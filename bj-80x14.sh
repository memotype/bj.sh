# (C) Isaac Freeman (memotype@gmail.com). See https://github.com/memotype/bj.sh
bj(){ declare -A bs=(['[']=] ['{']=});local gre='^[[:space:]]+(.*)' n i q wre="\
[[:space:]]*" ore='^(\[|\{)' xre='([eE][+-]?[0-9]+)?)' ol l b1 b2 x;local sre=^\
$wre'"(([^\"]|\\.)*)"' bre="^$wre(true|false|null)" fre=$wre'(,|\}|$)'$wre nre=\
'^(-?(0|[1-9][0-9]*)(\.[0-9]+)?'$xre;local j=$1 v= k= c;shift;for q;do n=0 x= c\
=1;[[ ${j:$i} =~ $gre ]]&&j=${BASH_REMATCH[1]};for ((i=1;i<${#j};i++));do if [[
${j:0:1} = '[' ]];then k=$((n++));elif [[ ${j:$i} =~ $sre$wre:$wre ]];then k=${\
BASH_REMATCH[1]};((i+=${#BASH_REMATCH[0]}));else return 2;fi;if [[ ${j:$i} =~ $\
sre || ${j:$i} =~ $nre || ${j:$i} =~ $bre ]];then v=${BASH_REMATCH[1]};((i+=${#\
BASH_REMATCH[0]}));elif [[ ${j:$i} =~ $ore ]];then ol=0;b1=${BASH_REMATCH[1]};b\
2=${bs[$b1]};for ((l="$i";l<"${#j}";l++));do case ${j:$l:1} in $b1)((ol++));;$b\
2)((ol--));((ol<1))&&break;;esac;done;v=${j:$i:$((l-i+1))};((i+=${#v}));fi;if [[
$k = "$q" ]];then x=$v c=0;break;fi;[[ ${j:$i} =~ ^$fre ]]&&((i+=${#BASH_REMATC\
H[0]}-1));done;j=$x;done;echo "$x";return "$c";}
