#!/bin/bash

# date:     2018-06-26
# version:  2.3
# author:   xereeto
# licence:  wtfpl
set -e
time=date +%s
tries=0
#trap "exit 1" TERM
#export TOP_PID=$$
export HOME="/home/pkobow"
wallpaper_path="$HOME/.wallpaper"
setup(){
	[[ -z $DISPLAY ]] && export DISPLAY=:0
	[[ -d $wallpaper_path ]] || mkdir $wallpaper_path
	[[ -f $wallpaper_path/subreddits ]] || echo -e "wallpapers\nwallpaper\nearthporn" > $wallpaper_path/subreddits
}
[[ -d $wallpaper_path ]] || setup
addJpegIfImgur(){
    while read url; do
        isImgur=$(echo "$url" | grep imgur);
        url=$(echo $url | sed -e 's/"url": "//' -e 's/",//' -e 's/gallery\///')
        [[ -z "$isImgur" ]] && echo $url || echo $url | sed -e 's/$/\.jpg/'
    done
}
startOver(){
    if [[ -z "$1" ]]; then echo "error"; else  echo $1; fi
    rm "$wallpaper_path/$time.jpg" 2>/dev/null;
    sleep 1
    getWallpaper "shitsfucked";
}
tr=0
setWallpaper(){
    echo "Setting wallpaper...."
  $HOME/scripts/set-wallpaper.sh "$1"
}
getWallpaper(){
	if [[ $tries > 100 ]]; then
	  echo "too many failed attempts, exiting";
		exit 1
	#kill -s TERM $TOP_PID;
	fi
	  tries=$((tries+1))
        [[ -z "$1" ]] || echo "that didn't work, let's try again"
        echo "getting wallpaper..."
        RESULT=$(curl -s -A "wallpaper bot" https://www.reddit.com/r/grep -v "#" $wallpaper_path/subreddits | shuf -n 1/.json | python3 -m json.tool | grep -P '\"url\": \"htt(p|ps):\/\/((i.+)?imgur.com\/(?!.\/)[A-z0-9]{5,7}|i.redd.it|staticflickr.com)' | addJpegIfImgur | shuf -n 1 - | xargs wget -O /tmp/$time.jpg 2>/dev/null)
		echo $RESULT
		echo "curled"
#check if file has actually been downloaded
		[[ ! -f "/tmp/$time.jpg" ]] && startOver "Image Not Downloaded to /tmp/$time.jpg"
        hash=$(sha256sum /tmp/$time.jpg | cut -d " " -f 1)
        [[ -f $wallpaper_path/$hash.jpg ]] && startOver "Already have this one"
        mv /tmp/$time.jpg  $wallpaper_path/$hash.jpg
        width=$(identify -format %w $wallpaper_path/$hash.jpg) 2>/dev/null
        height=$(identify -format %h $wallpaper_path/$hash.jpg) 2>/dev/null
        #TODO actually resize the image
		#[[ "$width" -ge 1920 && "$height" -ge 1080 ]] || startOver "Could not Resize"
        echo "Setting Image...."
        setWallpaper "$wallpaper_path/$hash.jpg"
		echo "Done"
		exit 0
#gsettings set org.gnome.desktop.background picture-uri-dark "'file://$wallpaper_path/$time.jpg'"
#gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path/$time.jpg" 2>/dev/null || startOver "Could not set Background"
}
getWallpaper
echo "hope you like your new wp"
