# Copyright (c) 2016 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or http://www.opensource.org/licenses/mit-license.php.

# What to do
sign=false
verify=false
build=true

# Systems to build
linux=true

# Other Basic variables
SIGNER="{{ gpg_key_name }}"
VERSION={{ zcash_version }}
commit=false
url={{ zcash_git_repo_url }}
proc=2
mem=3584
lxc=true
scriptName=$(basename -- "$0")
signProg="gpg --detach-sign"
commitFiles=true

gitian_builder_repo_path=${HOME}/gitian-builder
gitian_sigs_repo_path=${HOME}/gitian.sigs

zcash_repo_dir_path=${HOME}/zcash
gitian_descriptor_path=${zcash_repo_dir_path}/contrib/gitian-descriptors/gitian-linux.yml

zcash_binaries_dir_path=${HOME}/zcash-binaries

build_dir_path=${gitian_builder_repo_path}/build
suite_descriptors_dir_path=${gitian_builder_repo_path}/suites

# Help Message
read -d '' usage <<- EOF
Usage: $scriptName [-c|u|v|b|s|B|o|h|j|m|] signer version

Run this script from the directory containing the zcash, gitian-builder, and gitian.sigs repositories.

Arguments:
signer          GPG signer to sign each build assert file
version		Version number, commit, or branch to build. If building a commit or branch, the -c option must be specified

Options:
-c|--commit	Indicate that the version argument is for a commit or branch
-u|--url	Specify the URL of the repository. Default is {{ zcash_git_repo_url }}
-v|--verify 	Verify the gitian build
-b|--build	Do a gitian build
-s|--sign	Make signed binaries
-B|--buildsign	Build both signed and unsigned binaries
-j		Number of processes to use. Default 2
-m		Memory to allocate in MiB. Default 3584
--detach-sign   Create the assert file for detached signing. Will not commit anything.
--no-commit     Do not commit anything to git
-h|--help	Print this help message
EOF

# Get options and arguments
while :; do
    case $1 in
        # Verify
        -v|--verify)
	    verify=true
            ;;
        # Build
        -b|--build)
	    build=true
            ;;
        # Sign binaries
        -s|--sign)
	    sign=true
            ;;
        # Build then Sign
        -B|--buildsign)
	    sign=true
	    build=true
            ;;
        # PGP Signer
        -S|--signer)
	    if [ -n "$2" ]
	    then
		SIGNER=$2
		shift
	    else
		echo 'Error: "--signer" requires a non-empty argument.'
		exit 1
	    fi
           ;;
	# Help message
	-h|--help)
	    echo "$usage"
	    exit 0
	    ;;
	# Commit or branch
	-c|--commit)
	    commit=true
	    ;;
	# Number of Processes
	-j)
	    if [ -n "$2" ]
	    then
		proc=$2
		shift
	    else
		echo 'Error: "-j" requires an argument'
		exit 1
	    fi
	    ;;
	# Memory to allocate
	-m)
	    if [ -n "$2" ]
	    then
		mem=$2
		shift
	    else
		echo 'Error: "-m" requires an argument'
		exit 1
	    fi
	    ;;
	# URL
	-u)
	    if [ -n "$2" ]
	    then
		url=$2
		shift
	    else
		echo 'Error: "-u" requires an argument'
		exit 1
	    fi
	    ;;
        # Detach sign
        --detach-sign)
            signProg="true"
            commitFiles=false
            ;;
        # Commit files
        --no-commit)
            commitFiles=false
            ;;
	*)               # Default case: If no more options then break out of the loop.
             break
    esac
    shift
done

# Set up LXC
if [[ $lxc = true ]]
then
    source ~/.profile
fi

# Get version
if [[ -n "$1" ]]
then
    VERSION=$1
    COMMIT=$VERSION
    shift
fi

# Check that a signer is specified
if [[ $SIGNER == "" ]]
then
    echo "$scriptName: Missing signer."
    echo "Try $scriptName --help for more information"
    exit 1
fi

# Check that a version is specified
if [[ $VERSION == "" ]]
then
    echo "$scriptName: Missing version."
    echo "Try $scriptName --help for more information"
    exit 1
fi

# Add a "v" if no -c
if [[ $commit = false ]]
then
	COMMIT="${VERSION}"
fi
echo ${COMMIT}

# Set up build
pushd ${zcash_repo_dir_path}
git fetch
git checkout ${COMMIT}
popd


suites=$(explode_yaml_file.py ${gitian_descriptor_path} suites ${suite_descriptors_dir_path})

# Build
if [[ $build = true ]]
then
	# Make output folder
	mkdir -p ${zcash_binaries_dir_path}/${VERSION}

	# Linux
	if [[ $linux = true ]]
	then
        for suite in ${suites} ; do
            echo "processing suite ${suite}"

            suite_dir_path=${suite_descriptors_dir_path}/${suite}
            echo "suite_dir_path: ${suite_dir_path}"

            # Build Dependencies
            echo ""
            echo "Building Dependencies"
            echo ""
            pushd ${gitian_builder_repo_path}
            mkdir -p inputs
            rm -rf ${gitian_builder_repo_path}/cache/* # Clear cache directory before each build

            make -C ${zcash_repo_dir_path}/depends download SOURCES_PATH=${gitian_builder_repo_path}/cache/common

            suite_image_path=${gitian_builder_repo_path}/base-${suite}-amd64
            echo "suite_image_path: ${suite_image_path}"

            if [ ! -f ${suite_image_path} ]; then
                echo "Image not found for suite ${suite}; calling make-base-vm to build it"
                ./bin/make-base-vm --lxc --arch amd64 --distro debian --suite ${suite}
            fi

            echo ""
            echo "Compiling variant: ${VERSION}_${suite}"
            echo ""

            ./bin/gbuild -j ${proc} -m ${mem} --commit zcash=${COMMIT} --url zcash=${url} ${suite_dir_path}/gitian-linux.yml
            ./bin/gsign -p "$signProg" --signer "$SIGNER" --release ${VERSION}_${suite} --destination ${gitian_sigs_repo_path}/ ${suite_dir_path}/gitian-linux.yml

            suite_binaries_dir_path=${zcash_binaries_dir_path}/${VERSION}/${suite}
            mkdir ${suite_binaries_dir_path}

            mv ${build_dir_path}/out/zcash-*.tar.gz ${build_dir_path}/out/src/zcash-*.tar.gz ${suite_binaries_dir_path}

            popd  # pushd ${gitian_builder_repo_path}


            if [[ $commitFiles = true ]]
            then
	            # Commit to gitian.sigs repo
                echo ""
                echo "Committing ${VERSION} Signatures"
                echo ""
                pushd ${gitian_sigs_repo_path}
                git add ${VERSION}_${suite}/${SIGNER}
                git commit -a -m "Add ${VERSION}_${suite} signatures for ${SIGNER}"
                popd
            fi
        done
	fi
fi

# Verify the build
if [[ $verify = true ]]
then
    # Linux
    pushd ${gitian_builder_repo_path}

    for suite in ${suites} ; do
        echo "processing suite ${suite}"

        suite_dir_path=${suite_descriptors_dir_path}/${suite}
        echo "suite_dir_path: ${suite_dir_path}"

        echo ""
        echo "Verifying ${VERSION}_${suite} Linux"
        echo ""

        ./bin/gverify -v -d ${gitian_sigs_repo_path}/ -r ${VERSION}_${suite} ${suite_dir_path}/gitian-linux.yml
    done

    popd
fi

# Sign binaries
if [[ $sign = true ]]
then

    pushd ${gitian_builder_repo_path}
	popd

    if [[ $commitFiles = true ]]
    then
        # Commit Sigs
        pushd ${gitian_sigs_repo_path}
        echo ""
        echo "Committing ${VERSION} Signed Binary Signatures"
        echo ""
        git commit -a -m "Add ${VERSION} signed binary signatures for ${SIGNER}"
        popd
    fi
fi
