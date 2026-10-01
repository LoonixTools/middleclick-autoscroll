# shellcheck shell=bash
#
# Firefox, and everything else built on Gecko: LibreWolf, Zen, Floorp,
# Waterfox, Thunderbird.
#
# Gecko has autoscroll of its own, off on Linux. There is no command line flag
# for it, only a setting: general.autoScroll. Settings live in each profile, so
# the line goes into the profile's user.js, which Gecko reads at every start.
#
# Gecko copies what user.js sets into prefs.js. So undoing takes the line out
# of prefs.js as well. A browser that is still open would write it back when it
# quits, so for that profile user.js says false instead, and the record stays
# until the next undo can finish the job.

MCA_GECKO_BEGIN='// >>> middleclick-autoscroll'
MCA_GECKO_END='// <<< middleclick-autoscroll'
MCA_GECKO_ON='user_pref("general.autoScroll", true);'
MCA_GECKO_OFF='user_pref("general.autoScroll", false);'

# The profile folders one apply has done already, and the profiles.ini files
# the watcher should look at. Both are filled by mca_gecko_apply.
declare -A MCA_GECKO_SEEN=()
MCA_GECKO_WATCH=()

# Set by mca_gecko_revert when a profile is still open and has to be undone
# again later.
MCA_GECKO_PENDING=0

# _mca_gecko_rel <directory>
# Whether a Gecko application is installed there. If so, where it keeps its
# profiles, relative to the home or config folder, in MCA_GECKO_REL. Read from
# application.ini the way Gecko does it: [App] Profile= when it is set, else
# Vendor/Name, in lowercase.
MCA_GECKO_REL=''

_mca_gecko_rel() {
	local dir="$1" line group='' vendor='' name='' profile='' rel=''

	MCA_GECKO_REL=''
	[[ -e $dir/libxul.so && -r $dir/application.ini ]] || return 1

	while IFS= read -r line || [[ -n $line ]]; do
		line="${line%$'\r'}"
		case "$line" in
			'['*)      group="$line" ;;
			Vendor=*)  [[ $group == '[App]' ]] && vendor="${line#*=}" ;;
			Name=*)    [[ $group == '[App]' ]] && name="${line#*=}" ;;
			Profile=*) [[ $group == '[App]' ]] && profile="${line#*=}" ;;
		esac
	done < "$dir/application.ini"

	if [[ -n $profile ]]; then
		rel="${profile//\\//}"
		while [[ $rel == /* ]]; do rel="${rel#/}"; done
		rel="${rel#.}"
	elif [[ -n $name ]]; then
		rel="${vendor:+$vendor/}$name"
	fi

	# Gecko lowercases in ASCII. A Turkish locale turns I into a dotless ı.
	rel="${rel,,}"
	rel="${rel//ı/i}"

	[[ -n $rel && /$rel/ != */../* ]] || return 1
	MCA_GECKO_REL="$rel"
}

# _mca_gecko_tree <root> <depth>
# The same for a Flatpak or a snap, where libxul.so is somewhere in the tree.
_mca_gecko_tree() {
	local lib

	MCA_GECKO_REL=''
	[[ -d $1 ]] || return 1
	lib="$(find "$1" -maxdepth "$2" -name libxul.so -print -quit 2>/dev/null)"
	[[ -n $lib ]] && _mca_gecko_rel "${lib%/*}"
}

# mca_flatpak_gecko <app id> / mca_snap_gecko <snap name>
# Whether it is Gecko, with the folder in MCA_GECKO_REL. Memoized like the
# Chromium check, and an empty answer means no.
declare -A MCA_GECKO_MEMO=()

mca_flatpak_gecko() {
	local key="flatpak:$1"

	if [[ -z ${MCA_GECKO_MEMO[$key]+set} ]]; then
		MCA_GECKO_REL=''
		mca_flatpak_location "$1" && _mca_gecko_tree "$MCA_FLATPAK_AT/files" 4
		MCA_GECKO_MEMO[$key]="$MCA_GECKO_REL"
	fi

	MCA_GECKO_REL="${MCA_GECKO_MEMO[$key]}"
	[[ -n $MCA_GECKO_REL ]]
}

mca_snap_gecko() {
	local key="snap:$1" d

	if [[ -z ${MCA_GECKO_MEMO[$key]+set} ]]; then
		MCA_GECKO_REL=''
		for d in "${MCA_SNAP_DIRS[@]}"; do
			_mca_gecko_tree "$d/$1/current" 5 && break
		done
		MCA_GECKO_MEMO[$key]="$MCA_GECKO_REL"
	fi

	MCA_GECKO_REL="${MCA_GECKO_MEMO[$key]}"
	[[ -n $MCA_GECKO_REL ]]
}

# mca_gecko_roots <rel> <packaging> <name>
# Every folder that can hold the application's profiles.ini. An older install
# uses ~/.<rel>. A new one (Firefox 147 and later) uses $XDG_CONFIG_HOME/<rel>,
# or ~/<rel> for a fork with a profile name of its own. A Flatpak or a snap has
# the same inside its own folder.
mca_gecko_roots() {
	local rel="$1" packaging="$2" name="$3" d

	case "$packaging" in
		flatpak)
			printf '%s\n' "$HOME/.var/app/$name/.$rel" "$HOME/.var/app/$name/config/$rel"
			;;
		snap)
			for d in common current; do
				printf '%s\n' "$HOME/snap/$name/$d/.$rel" "$HOME/snap/$name/$d/.config/$rel"
			done
			;;
		*)
			printf '%s\n' "$HOME/.$rel" "$MCA_XDG_CONFIG/$rel"
			[[ $rel == */* ]] || printf '%s\n' "$HOME/$rel"
			;;
	esac
}

# mca_gecko_profiles <root>
# Every profile folder that profiles.ini there lists.
mca_gecko_profiles() {
	local root="$1" line path='' relative=1 inprofile=0

	[[ -r $root/profiles.ini ]] || return 0

	while IFS= read -r line || [[ -n $line ]]; do
		line="${line%$'\r'}"
		case "$line" in
			'['*)
				_mca_gecko_profile_emit
				[[ $line == '[Profile'* ]] && inprofile=1 || inprofile=0
				path='' relative=1
				;;
			Path=*)       path="${line#Path=}" ;;
			IsRelative=*) relative="${line#IsRelative=}" ;;
		esac
	done < "$root/profiles.ini"
	_mca_gecko_profile_emit
}

_mca_gecko_profile_emit() {
	(( inprofile )) && [[ -n $path ]] || return 0
	[[ $relative == 1 ]] && path="$root/$path"
	[[ -d $path ]] && printf '%s\n' "$path"
	return 0
}

# _mca_gecko_write <user.js> <line>
# Puts the line into user.js as a marked block, replacing an older block.
# Returns like mca_write_if_changed.
_mca_gecko_write() {
	local file="$1" line="$2" content=''

	[[ -f $file ]] && content="$(_mca_flags_drop_block "$file" "$MCA_GECKO_BEGIN" "$MCA_GECKO_END")"
	content="${content:+$content$'\n'}$MCA_GECKO_BEGIN"$'\n'"$line"$'\n'"$MCA_GECKO_END"
	mca_write_if_changed "$file" "$content"$'\n'
}

# mca_gecko_apply <rel> <packaging> <name>
# Turns autoscroll on in every profile of the application.
mca_gecko_apply() {
	local root profile

	while IFS= read -r root; do
		[[ -n ${MCA_GECKO_SEEN[$root]+set} ]] && continue
		MCA_GECKO_SEEN[$root]=1

		# A new profile is written into profiles.ini, so the watcher can pick
		# it up.
		MCA_GECKO_WATCH+=("$root/profiles.ini")

		while IFS= read -r profile; do
			_mca_gecko_profile_apply "$profile"
		done < <(mca_gecko_profiles "$root")
	done < <(mca_gecko_roots "$@")
}

_mca_gecko_profile_apply() {
	local dir="$1" file="$1/user.js" detail=created

	# A user.js that links somewhere else is part of a setup of its own.
	[[ -L $file ]] && return 0
	[[ -f $file ]] && detail=block

	if ! grep -qxF -- "$MCA_GECKO_BEGIN" "$file" 2>/dev/null; then
		# Set by the user already, in user.js or in the browser's own
		# settings. Their choice: nothing is written and nothing recorded.
		grep -qE '^[[:space:]]*user_pref\([[:space:]]*"general\.autoScroll"' \
			-- "$file" 2>/dev/null && return 0
		grep -qxF -- "$MCA_GECKO_ON" "$dir/prefs.js" 2>/dev/null && return 0
	fi

	_mca_gecko_write "$file" "$MCA_GECKO_ON"
	case $? in
		0) MCA_CHANGES=$(( MCA_CHANGES + 1 )) ;;
		2) return 0 ;;
	esac

	# A file this program created stays one it created.
	mca_ledger_has "$file" && detail="$(mca_ledger_detail "$file")"
	mca_ledger_add gecko "$file" "$detail"
}

# mca_gecko_revert <user.js> <created|block>
# Returns 0 when something changed. Sets MCA_GECKO_PENDING when the profile is
# open and the record has to stay.
mca_gecko_revert() {
	local file="$1" detail="$2" dir="${1%/*}" prefs content tmp rc=0

	MCA_GECKO_PENDING=0
	[[ -f $file && ! -L $file ]] || return 1
	grep -qxF -- "$MCA_GECKO_BEGIN" "$file" 2>/dev/null || return 1

	# The lock link only exists while the profile is open.
	if [[ -L $dir/lock ]]; then
		MCA_GECKO_PENDING=1
		_mca_gecko_write "$file" "$MCA_GECKO_OFF"
		return
	fi

	content="$(_mca_flags_drop_block "$file" "$MCA_GECKO_BEGIN" "$MCA_GECKO_END")"
	if [[ $detail == created && -z ${content//[[:space:]]/} ]]; then
		rm -f -- "$file"
	else
		printf '%s\n' "$content" > "$file"
	fi

	prefs="$dir/prefs.js"
	if [[ -f $prefs && ! -L $prefs ]] && grep -qxF -- "$MCA_GECKO_ON" "$prefs"; then
		tmp="$(mktemp "$prefs.XXXXXX")" || return 0
		chmod --reference="$prefs" -- "$tmp" 2>/dev/null || chmod 600 -- "$tmp"
		# grep says 1 when no line is left, which is fine here.
		grep -vxF -- "$MCA_GECKO_ON" "$prefs" > "$tmp" || rc=$?
		if (( rc <= 1 )); then mv -f -- "$tmp" "$prefs"; else rm -f -- "$tmp"; fi
	fi
	return 0
}
