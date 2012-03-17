#!/bin/bash

set -e

declare -i noProcessed=0

for i in $( ls -1 --hide=disabled simple ); do
	echo -e "\033[32mRunning test case: simple."$i"\033[0m"
	#valgrind --error-exitcode=1 --quiet --gen-suppressions=yes --tool=helgrind luanode run.lua simple.$i
	#valgrind --error-exitcode=1 --db-attach=yes --quiet --suppressions=suppressions.supp --leak-check=full --show-reachable=yes --tool=memcheck luanode run.lua simple.$i
	#valgrind --error-exitcode=1 --num-callers=30 --leak-check=full --show-reachable=yes --suppressions=suppressions.supp --gen-suppressions=yes luanode run.lua simple.$i
	luanode_d run.lua simple.$i

	if [ $? -ne 0 ]
	then
		echo -e "\0331m\033[41mTest case failed: " $i "\033[0m"
		break;
	fi
	((noProcessed=noProcessed+1))
done

echo "Ran $noProcessed tests. Ended without errors."
