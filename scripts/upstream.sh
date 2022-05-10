#!/usr/bin/env bash
# get base dir regardless of execution location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
. $(dirname $SOURCE)/init.sh

git submodule update --init --recursive

if [[ "$1" == up* ]]; then
    (
        cd "$basedir/Purpur/"
        git fetch origin ver/1.16.5 && git reset --hard origin/ver/1.16.5
        cd ../
        git add Purpur
    )
fi

purpurVer=$(gethead Purpur)
cd "$basedir/Purpur/"

./gradlew applyPatches || exit 1

cd "Purpur-Server"
mcVer=$(mvn -o org.apache.maven.plugins:maven-help-plugin:3.2.0:evaluate -Dexpression=minecraft_version | sed -n -e '/^\[.*\]/ !{ /^[0-9]/ { p; q } }')

basedir
. "$basedir"/scripts/importmcdev.sh

minecraftversion=$(cat "$basedir"/Purpur/Paper/work/BuildData/info.json | grep minecraftVersion | cut -d '"' -f 4)
version=$(echo -e "Purpur: $purpurVer\nmc-dev:$importedmcdev")
tag="${minecraftversion}-${mcVer}-$(echo -e $version | shasum | awk '{print $1}')"
echo "$tag" > "$basedir"/current-purpur

"$basedir"/scripts/generatesources.sh

cd Purpur/

function tag {
(
    cd $1
    if [ "$2" == "1" ]; then
        git tag -d "$tag" 2>/dev/null
    fi
    echo -e "$(date)\n\n$version" | git tag -a "$tag" -F - 2>/dev/null
)
}
echo "Tagging as $tag"
echo -e "$version"

forcetag=0
if [ "$(cat "$basedir"/current-purpur)" != "$tag" ]; then
    forcetag=1
fi

tag Purpur-API $forcetag
tag Purpur-Server $forcetag

pushRepo Purpur-API $PURPUR_API_REPO $tag
pushRepo Purpur-Server $PURPUR_SERVER_REPO $tag

