# (C) Isaac Freeman (memotype@gmail.com). See https://github.com/memotype/bj.sh
bj()([[ $1 = - ]]||exec<<<"$1";shift;c=;rd(){ l=$c;IFS= read -rd '' -n1 c;};pr\
(){ printf "%s" "${o[@]}";};st(){ p=$1;[[ ! $p ]]&&o=();while rd;do [[ $p&& ! \
$q ]]&&o+=("$l");case "$l$c" in \\?)[[ $p ]]||{ o+=("$c");c=c;};;?\\):;;?\")
break;;*)[[ $p ]]||o+=("$c");;esac;done;};ob(){ b=1;while rd;do [[ ! $q ]]&&o+=\
("$l");case "$c" in {)((b++));;\})((b--));[[ $b = 0 ]]&&{ [[ $q ]]&&return 1;o\
+=(});break;};;\")[[ $q ]]&&{ st;k=$(pr);}||st 1;;:)[[ $q&&$k = "$q" ]]&&return
;;esac;done;};lt(){ [[ $q = 0 ]]&&return;n=0 b=1;while rd;do [[ ! $q ]]&&o+=(\
"$l");case "$b$c" in ?\")st 1;;?[|?{)((b++));;?})((b--));;?])((b--));[[ $b = 0 \
]]&&{ [[ $q ]]&&return 1;o+=(]);break;};;1,)((n++));[[ $n = "$q" ]]&&break;;esac
done;};vl(){ o=();while rd&&o+=("$l")&&[[ $c =~ $1 ]];do :;done;};for q in \
"$@" "";do [[ $q ]]&&x=1;f= o=();while rd;do case $c in [[:space:]]):;;\")st; f\
=1;;t|f|n)vl "[a-z]";f=1;;-|[0-9])vl "[-0-9\.eE+]";f=1;;{)ob&&f=1;;[)lt&&f=1;;*)
return 2;;esac;[[ $f ]]&&{ x=0;break;};done;done;pr;return $x;)
