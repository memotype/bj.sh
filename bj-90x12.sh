# (C) Isaac Freeman (memotype@gmail.com). See https://github.com/memotype/bj.sh
bj()([[ $1 = - ]]||exec<<<"$1";shift;c=;rd(){ l=$c;IFS= read -rd '' -n1 c;};pr(){ printf \
"%s" "${o[@]}";};st(){ o=();while rd;do case "$l$c" in \\?)o+=("$c");c=c;;?\\):;;?\")brea\
k;;*)o+=("$c");;esac;done;};ob(){ bl=1;while rd;do [[ ! $q ]]&&o+=("$l");case "$c" in {)(\
(bl++));;\})((bl--));[[ $bl = 0 ]]&&{ [[ $q ]]&&return 1;o+=(});break;};;\")[[ $q ]]&&{ s\
t;k=$(pr);};;:)[[ $q&&$k = "$q" ]]&&return;;esac;done;};lt(){ [[ $q = 0 ]]&&return;n=0 bl\
=1;while rd;do [[ ! $q ]]&&o+=("$l");case "$bl$c" in ?[|?{)((bl++));;?})((bl--));;?])((bl\
--));[[ $bl = 0 ]]&&{ [[ $q ]]&&return 1;o+=(]);break;};;1,)((n++));[[ $n = "$q" ]]&&brea\
k;;esac;done;};nm(){ o=();while rd&&o+=("$l")&&[[ $c =~ [-0-9\.eE\+] ]];do :;done;};tf(){
o=();while rd&&o+=("$l")&&[[ $c =~ [a-z] ]];do :;done;};for q in "$@" "";do [[ $q ]]&&x=1
f= o=();while rd;do case $c in [[:space:]]):;;\")st;f=1;;t|f|n)tf;f=1;;-|[0-9])nm;f=1;;{)
ob&&f=1;;[)lt&&f=1;;*)return 2;;esac;[[ $f ]]&&{ x=0;break;};done;done;pr;return $x;)
