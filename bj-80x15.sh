# (C) Isaac Freeman (memotype@gmail.com). See https://github.com/memotype/bj.sh
bj(){ declare -A bs=(['[']=] ['{']=});local gre='^[[:space:]]+(.*)' wre=\
'[[:space:]]*' ore='^(\[|\{)' xre='([eE][+-]?[0-9]+)?)';local sre=\
^$wre'"(([^\"]|\\.)*)"' bre="^$wre(true|false|null)" fre="$wre(,|\\}|\$)$wre" \
nre='^(-?(0|[1-9][0-9]*)(\.[0-9]+)?'$xre;local j=$1 v= k= n i q ol l b1 b2 x c
shift;for q in "$@";do n=0 x= c=1;[[ ${j:$i} =~ $gre ]]&&j=${BASH_REMATCH[1]}
for ((i=1;i<${#j};i++));do if [[ ${j:0:1} = '[' ]];then k=$((n++));elif [[ ${\
j:$i} =~ $sre$wre:$wre ]];then k=${BASH_REMATCH[1]};((i+=${#BASH_REMATCH[0]}))
else return 2;fi;if [[ ${j:$i} =~ $sre || ${j:$i} =~ $nre || ${j:$i} =~ $bre ]]
then v=${BASH_REMATCH[1]};((i+=${#BASH_REMATCH[0]}));elif [[ ${j:$i} =~ $ore ]]
then ol=0;b1=${BASH_REMATCH[1]};b2=${bs[$b1]};for ((l="$i";l<"${#j}";l++));do
case ${j:$l:1} in $b1)((ol++));;$b2)((ol--));((ol<1))&&break;;esac;done;v=${\
j:$i:$((l-i+1))};((i+=${#v}));fi;if [[ $k = "$q" ]];then x=$v c=0;break;fi;if [[
${j:$i} =~ ^$fre ]];then ((i+=${#BASH_REMATCH[0]}-1));fi;done;j=$x;done;echo \
"$x";return "$c";}
