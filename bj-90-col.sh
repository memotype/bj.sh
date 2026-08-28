# (C) Isaac Freeman (memotype@gmail.com). See https://github.com/memotype/bj.sh
bj()([[ $1 = - ]]||exec<<<"$1";shift;c=;rd(){ l=$c;IFS= read -rN1 c;};pr(){ printf %s \
"${o[@]}";};st(){ p=$1;[[ $p ]]||o=();while rd;do [[ $p&&! $q ]]&&o+=("$l");case $c in \\)
rd||break;[[ $p&&$q ]]||o+=("$l${c::!p}");;\")break;;*)[[ $p ]]||o+=("$c");;esac;done;}
co(){ [[ $1&&$q = 0 ]]&&return;n=0 b=1;while rd;do [[ $q ]]||o+=("$l");case $c in \")[[ \
$1||! $q ]]&&st 1||{ st;k=$(pr);};;[|{)((b++));;]|\})((--b))||{ [[ $q ]]&&exit 1;o+=("$c")
break;};;:)[[ ! $1&&$q&&$k = "$q" ]]&&return;;,)[[ $1&&$b = 1 ]]&&{ ((n++));[[ $n = "$q" \
]]&&break;};;esac;done;};for q in "$@" "";do x=1;o=();while rd;do case $c in [[:space:]])
false;;\")st;;[tfn0-9-])o=();while o+=("$c")&&rd&&[[ $c =~ [-+.0-9Ea-z] ]];do :;done;;{)co
;;[)co 1;;*)return 2;;esac&&{ x=0;break;};done;done;pr;return $x;)
