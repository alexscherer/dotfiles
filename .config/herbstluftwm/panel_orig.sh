#!/usr/bin/env bash

quote() {
	local q="$(printf '%q ' "$@")"
	printf '%s' "${q% }"
}

hc_quoted="$(quote "${herbstclient_command[@]:-herbstclient}")"
hc() { "${herbstclient_command[@]:-herbstclient}" "$@" ;}
monitor=${1:-0}
geometry=( $(hc monitor_rect "$monitor") )
if [ -z "$geometry" ] ;then
    echo "Invalid monitor $monitor"
    exit 1
fi
# geometry has the format W H X Y
x=${geometry[0]}
y=${geometry[1]}
panel_width=${geometry[2]}
panel_height=24
panel_expanded_height=120
font="-*-hack-*-*-*-*-14-*-*-*-*-*-*-*"
fontBold=""
bgcolor=$(hc get frame_border_normal_color)
selbg=$(hc get window_border_active_color)
selfg='#101010'


titleOffset=0
titleMaxLength=40
titleMaxLengthLore=40
titleScrollStep=5

mpdOffset=0
mpdScrollStep=2

iconTime=""

        white_bright='#efefef'
        white_dark='#909090'
        green_dark='#182f1b'
        green_bright='#7fb069'
        orange='#d36135'
        yellow='#b3a81b'
        red='#550c18'

        decopath="/home/alex/.bootstrap/xbm"

        # diagonal corner
        deco_dc_tl="^i($decopath/dc-024-tl.xbm)"
        deco_dc_tr="^i($decopath/dc-024-tr.xbm)"
        deco_dc_bl="^i($decopath/dc-024-bl.xbm)"
        deco_dc_br="^i($decopath/dc-024-br.xbm)"

        # single arrow and double arrow
        deco_sa_l="^i($decopath/sa-024-l.xbm)"
        deco_sa_r="^i($decopath/sa-024-r.xbm)"
        deco_da_l="^i($decopath/da-024-l.xbm)"
        deco_da_r="^i($decopath/da-024-r.xbm)"


####
# Try to find textwidth binary.
# In e.g. Ubuntu, this is named dzen2-textwidth.
if which textwidth &> /dev/null ; then
    textwidth="textwidth";
elif which dzen2-textwidth &> /dev/null ; then
    textwidth="dzen2-textwidth";
else
    echo "This script requires the textwidth tool of the dzen2 project."
    exit 1
fi
####
# true if we are using the svn version of dzen2
# depending on version/distribution, this seems to have version strings like
# "dzen-" or "dzen-x.x.x-svn"
if dzen2 -v 2>&1 | head -n 1 | grep -q '^dzen-\([^,]*-svn\|\),'; then
    dzen2_svn="true"
else
    dzen2_svn=""
fi

if awk -Wv 2>/dev/null | head -1 | grep -q '^mawk'; then
    # mawk needs "-W interactive" to line-buffer stdout correctly
    # http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=593504
    uniq_linebuffered() {
      awk -W interactive '$0 != l { print ; l=$0 ; fflush(); }' "$@"
    }
else
    # other awk versions (e.g. gawk) issue a warning with "-W interactive", so
    # we don't want to use it there.
    uniq_linebuffered() {
      awk '$0 != l { print ; l=$0 ; fflush(); }' "$@"
    }
fi

hc pad $monitor $panel_height

{
    ### Event generator ###
    # based on different input data (mpc, date, hlwm hooks, ...) this generates events, formed like this:
    #   <eventname>\t<data> [...]
    # e.g.
    #   date    ^fg(#efefef)18:33^fg(#909090), 2013-10-^fg(#efefef)29

    # Powerline / Color settings


        #arrow="^fn(powerlinesymbols-20)^fn()"
        arrow_right="$deco_sa_r"
        arrow_left="$deco_sa_l"

    #mpc idleloop player &
    while true ; do
        # "date" output is checked once a second, but an event is only
        # generated if the output changed compared to the previous run.
        #date +$'date\t^bg(#182f1b)^fg($white_bright)%H:%M:%S^fg($white_dark), %Y-%m-^fg($white_bright)%d^fg($white_bright)'



        date +$'date\t^bg('$green_dark')^fg('$green_bright')# %Y-%M-%d | %H:%M:%S'

        sleep 1 || break
    done > >(uniq_linebuffered) &
    childpid=$!
    hc --idle
    kill $childpid
} 2> /dev/null | {
    IFS=$'\t' read -ra tags <<< "$(hc tag_status $monitor)"
    visible=true
    date=""
    windowtitle=""
    while true ; do

        mpd_ctrl=$(mpc --host 192.168.254.31 current)

        ### Output ###
        # This part prints dzen data based on the _previous_ data handling run,
        # and then waits for the next event to happen.

        separator="^bg()^fg($selbg)|"

        # draw tags
        for i in "${tags[@]}" ; do
            case ${i:0:1} in
                '#')
                    echo -n "^bg(#7fb069)^fg($selfg)"
                    ;;
                '+')
                    echo -n "^bg($yellow)^fg($green_dark)"
                    ;;
                ':')
                    echo -n "^bg()^fg($white_bright)"
                    ;;
                '!')
                    echo -n "^bg($orange)^fg($green_dark)"
                    ;;
                '%')
                    echo -n "^bg($orange)^fg($green_dark)"
                    ;;
                *)
                    echo -n "^bg()^fg(#ababab)"
                    ;;
            esac
            if [ ! -z "$dzen2_svn" ] ; then
                # clickable tags if using SVN dzen
                echo -n "^ca(1,$hc_quoted focus_monitor \"$monitor\" && "
                echo -n "$hc_quoted use \"${i:1}\") ${i:1} ^ca()"
            else
                # non-clickable tags if using older dzen
                echo -n " ${i:1} "
            fi
        done
        echo -n "^fg($green_dark)^bg($green_bright)$deco_sa_r"
        titleOutput=""
        titleContent="${windowtitle//^/^^}"
        ellipsis=""
        separator="^bg($green_dark)^fg($green_bright)$deco_sa_r $deco_sa_l^bg($green_bright)^fg($green_dark)"
            titleOutput="$titleContent"
        if [ "${#titleContent}" -gt $titleMaxLength ] ; then

            ### ${#titleContent} - $titleOffset < 90
            if [ "$((${#titleContent} - $titleOffset - 3))" -lt $titleMaxLength ] ; then
                titleOutput=${titleContent:$titleOffset:$((${#titleContent}-3))}$separator${titleContent:0:$titleOffset}
            else
                titleOutput=${titleContent:$titleOffset:$titleMaxLength}
            fi


            if [ $titleOffset -lt $titleMaxLength ] ; then
                titleOffset=$(($titleOffset+$titleScrollStep))
            else
                titleOffset=0
            fi

        else
            titleOffset=0


        fi
        echo -n "^bg($green_bright)^fg($green_dark)$titleOutput$ellipsis^fg($green_bright)^bg($green_dark)$deco_da_r"


        #mpdMaxLengthLocal=15
        mpdOutput=""
        mpdPlayButton="^ca(1,$hc_quoted spawn lmc toggle)"
        mpdNextButton="^ca(1,$hc_quoted spawn lmc next)"
        mpdPrevButton="^ca(1,$hc_quoted spawn lmc prev)"
        mpdButtonEnd="^ca()"
        mpdContent="$mpd_ctrl"
        titleLength=${#titleOutput}
        if [ "$titleLength" -lt $titleMaxLengthLore ] ; then
            mpdMaxLengthLocal=$((($titleMaxLengthLore-$titleLength)*2))
        else
            mpdMaxLengthLocal=30
        fi

        mpdContentLength=${#mpdContent}

        if [ "$mpdOffset" -ge $mpdContentLength ] ; then
            mpdOffset=0
        fi

        ellipsis=""
            mpdOutput="$mpdContent"
        if [ "$mpdContentLength" -gt $mpdMaxLengthLocal ] ; then
            ellipsis=""
            if [ "$mpdOffset" -lt $mpdMaxLengthLocal ] ; then
                mpdOffset=$(($mpdOffset+$mpdScrollStep))
            else
                ### ${#titleContent} - $titleOffset < 90
                if [ "$(($mpdContentLength - $mpdOffset))" -lt $mpdMaxLengthLocal ] ; then
                    mpdOutput=${mpdContent:$mpdOffset:$mpdContentLength}${mpdContent:0:$mpdOffset}
                else
                    mpdOutput=${mpdContent:$mpdOffset:$mpdMaxLengthLocal}
                fi

            fi


        else
            mpdOffset=0


        fi

        mpdState=$(mpc --host=192.168.254.31 | grep -oP "\[[a-z]+\]")

        mpdColor=$green_bright
        if [ "$mpdState" == "[paused]" ] ; then
            mpdColor=$orange
        elif [ "$mpdState" == "[playing]" ] ; then
            mpdColor=$yellow
        fi

        center="^fg($mpdColor)$mpdPrevButton$deco_sa_l$mpdButtonEnd^bg($mpdColor)^fg($green_dark)$mpdPlayButton$mpdOutput$mpdButtonEnd^fg($mpdColor)^bg($green_dark)$mpdNextButton$deco_sa_r$mpdButtonEnd"
        center_text_only=$(echo -n "$center" | sed 's.\^[^(]*([^)]*)..g')
        centerwidth=$($textwidth "$font" "$center_text_only")
        echo -n "^pa($(($panel_width/2 - $centerwidth/2)))$center"





        right_mpd_progress=$(mpc --host=192.168.254.31 | grep -oP "#[0-9]+\/[0-9]+\s+[0-9]+:[0-9]+\/[0-9]+:[0-9]+")
        right_mpd_volume=$(sed -Ee "s/\s([0-9]+)//" <<<`pulsemixer --get-volume`)

        right_mpd_volume_output=$(echo $right_mpd_volume | dbar -w 4 -max 100 -min 0  -l 'Vol')

        # small adjustments
        right_mpd="^fg($orange)$deco_da_l^bg($orange)^fg($green_dark)$right_mpd_progress - $right_mpd_volume_output^fg(#7fb069)^i(/home/alex/.bootstrap/xbm/sa-024-l.xbm)"
        right_uptime="^bg(#7fb069)^fg($green_dark)$(uptime -p)"
        right_end="^fg(#182f1b)^i(/home/alex/.bootstrap/xbm/sa-024-r.xbm)"
        right="$right_mpd$right_uptime^fg(#182f1b)^i(/home/alex/.bootstrap/xbm/sa-024-l.xbm)$date"
        right_icons_replaced=$(echo -n "$right" | sed 's.\^i([^)]*).  .g')
        right_text_only=$(echo -n "$right_icons_replaced" | sed 's.\^[^(]*([^)]*)..g')
        right_end_text_only=$(echo -n "$right_end" | sed 's.\^[^(]*([^)]*)..g')
        # get width of right aligned text.. and add some space..
        width=$($textwidth "$font" "$right_text_only ")
        echo -n "^pa($(($panel_width - $width)))$right"
        echo

        ### Data handling ###
        # This part handles the events generated in the event loop, and sets
        # internal variables based on them. The event and its arguments are
        # read into the array cmd, then action is taken depending on the event
        # name.
        # "Special" events (quit_panel/togglehidepanel/reload) are also handled
        # here.

        # wait for next event
        IFS=$'\t' read -ra cmd || break
        # find out event origin
        case "${cmd[0]}" in
            tag*)
                #echo "resetting tags" >&2
                IFS=$'\t' read -ra tags <<< "$(hc tag_status $monitor)"
                ;;
            date)
                #echo "resetting date" >&2
                date="${cmd[@]:1}"
                date_text="${cmd[@]:1}"
                date_gen="${cmd[@]:1}"
                ;;
            date_text)
                date_text="${cmd[@]:1}"
                ;;
            text)
                text=""
                ;;
            quit_panel)
                exit
                ;;
            togglehidepanel)
                currentmonidx=$(hc list_monitors | sed -n '/\[FOCUS\]$/s/:.*//p')
                if [ "${cmd[1]}" -ne "$monitor" ] ; then
                    continue
                fi
                if [ "${cmd[1]}" = "current" ] && [ "$currentmonidx" -ne "$monitor" ] ; then
                    continue
                fi
                echo "^togglehide()"
                if $visible ; then
                    visible=false
                    hc pad $monitor 0
                else
                    visible=true
                    hc pad $monitor $panel_height
                fi
                ;;
            reload)
                exit
                ;;
            focus_changed|window_title_changed)
                windowtitle="${cmd[@]:2}"
                ;;
            #player)
            #    ;;
        esac
    done

    ### dzen2 ###
    # After the data is gathered and processed, the output of the previous block
    # gets piped to dzen2.
#
} 2> panel.log | dzen2 -w $panel_width -x $x -y $y -fn "$font" -h $panel_height \
    -e "button3=;button4=exec:$hc_quoted use_index -1;button5=exec:$hc_quoted use_index +1" \
    -ta l -bg "$green_dark" -fg '#efefef'
