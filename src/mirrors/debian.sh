check() {
	source_os_release
	result=0
	[ "$NAME" = "Debian GNU/Linux" ] || result=$?
	return $result
}

install() {
	config_file="/etc/apt/sources.list"

	if ! [ -f $config_file ]; then # rule for docker
		config_file="/etc/apt/sources.list.d/debian.list"
	fi

	source_os_release
	codename=${VERSION_CODENAME}
	echo "$PRETTY_NAME" | grep "sid" > /dev/null && {
		if [ "$HM_DEBIAN_SID" = "true" ]; then
			codename="sid"
		else
			print_warning "hustmirror cannot distinguish sid or testing"
			get_input "Please input codename (sid/testing): " "testing"
			codename="$input"
		fi
	}

	set_sudo

	if [ -f $config_file ]; then
		$sudo cp ${config_file} ${config_file}.bak || {
			print_error "Failed to backup ${config_file}"
			return 1
		}
	else
		print_warning "No ${config_file} found, creating new one"
	fi

	secure_url="${http}://${domain}/debian-security/"
	confirm_y "Use official secure source?" && \
		secure_url="${http}://security.debian.org/debian-security"

	src_prefix="# "
	confirm "Use source code?" && \
		src_prefix=""


	security_appendix='-security'
	[ "$codename" = "buster" ] && security_appendix='/updates'

	NFW=''
	if [ "$codename" = "bookworm" ] || [ "$codename" = "sid" ] || [ "$codename" = "testing" ]; then
	  NFW=' non-free-firmware'	
	fi

	if [ "$codename" = "sid" ]; then
		sid_prefix="# "
	fi


	$sudo sh -e -c "cat << EOF > ${config_file}
# ${gen_tag}
deb ${http}://${domain}/debian ${codename} main contrib non-free${NFW}
${src_prefix}deb-src ${http}://${domain}/debian ${codename} main contrib non-free${NFW}

${sid_prefix}deb ${http}://${domain}/debian ${codename}-updates main contrib non-free${NFW}
${sid_prefix}${src_prefix}deb-src ${http}://${domain}/debian ${codename}-updates main contrib non-free${NFW}

${sid_prefix}deb ${http}://${domain}/debian ${codename}-backports main contrib non-free${NFW}
${sid_prefix}${src_prefix}deb-src ${http}://${domain}/debian ${codename}-backports main contrib non-free${NFW}

${sid_prefix}deb ${secure_url} ${codename}${security_appendix} main contrib non-free${NFW}
${sid_prefix}${src_prefix}deb-src ${http}://security.debian.org/debian-security ${codename}${security_appendix} main contrib non-free${NFW}

EOF" || {
		print_error "Failed to add mirror to ${config_file}"
		return 1
	}

	confirm_y "Do you want to apt update?" && {
		$sudo apt update || {
			print_error "apt update failed"
			return 1
		}
	}

}

uninstall() {
	config_file="/etc/apt/sources.list"
	set_sudo
	$sudo mv ${config_file}.bak ${config_file} || {
		print_error "Failed to recover ${config_file}"
		return 1
	}
}

is_deployed() {
	config_file="/etc/apt/sources.list"
	result=0
	$sudo grep -q "${gen_tag}" ${config_file} || result=$?
	return $result
}

can_recover() {
	bak_file="/etc/apt/sources.list.bak"
	result=0
	test -f $bak_file || result=$?
	return $result
}

# vim: set filetype=sh ts=4 sw=4 noexpandtab:
