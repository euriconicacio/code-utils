#!/bin/bash

set -e
set -u 

[[ ${debug:-} ]] && set -x

[[ ${repack:-} == "" ]] && repack=true

set +x
export PATH=/cygdrive/c/Program\ Files\ \(x86\)/Git/bin:${PATH}
export PATH=/cygdrive/c/Cygwin/bin:${PATH}

export PATH=/c/Program\ Files\ \(x86\)/Git/bin:${PATH}

export PATH=/c/Program\ Files/Git/usr/bin/:${PATH}
export PATH=/c/Program\ Files/Git/bin/:${PATH}
export PATH=/c/Program\ Files/Git/mingw64/bin/:${PATH}

export PATH=/c/Cygwin/bin:${PATH}
export PATH=/usr/bin:${PATH}


which find
which sort

echo $PATH
if [[ "${WORKSPACE:-}" == "" ]]; then
  export WORKSPACE=`pwd`
fi
if [[ "${1:-}" != "" ]]; then
  test -e ${1} && cd ${1}
fi
echo
echo "Analyzing git in: `pwd` "
echo "Saving outfiles in: ${WORKSPACE}"
echo

rm -f ${WORKSPACE}/bigtosmall_*.txt
rm -f ${WORKSPACE}/bigobjects*.txt
rm -f ${WORKSPACE}/allfileshas*.txt

if [ -d .git ]; then
  export pack_dir=".git/objects"
else
  gitdir=`cat .git | awk -F ": " '{print $2}'`
  cd $gitdir
  export pack_dir="./objects"
fi

# List sizes before 
[[ -d .git/objects ]] && du -sh .git/objects
[[ -d .git/lfs ]] && du -sh .git/lfs
[[ -d .git/modules ]] && du -sh .git/modules
du -sh .git

if [[ ${repack} == "true" ]]; then
  # reference: https://stackoverflow.com/questions/28720151/git-gc-aggressive-vs-git-repack
  git reflog expire --all --expire=now
  git repack -a -d --depth=250 --window=250 # accept to use old deltas - add "-f" option to not reuse old deltas for large repos it fails often
  git gc --prune
fi

[[ -d .git/objects ]] && du -sh .git/objects
du -sh .git

git rev-list --objects --all  > ${WORKSPACE}/allfileshas.txt
cat ${WORKSPACE}/allfileshas.txt| cut -d ' ' -f 2-  | uniq > ${WORKSPACE}/allfileshas_uniq.txt

export pack_file=$(find ${pack_dir} -name '*.idx')

echo "START: Investigate blobs that are directly stored in idx file: ${pack_file}"
git verify-pack -v ${pack_file} | egrep "^\w+ blob\W+[0-9]+ [0-9]+ [0-9]+$" | awk -F" " '{print $1,$2,$3,$4,$5}' > ${WORKSPACE}/bigobjects.txt

join <(sort ${WORKSPACE}/bigobjects.txt) <(sort ${WORKSPACE}/allfileshas.txt) | sort -k 3 -n -r | cut -f 1,3,6-  -d ' ' > ${WORKSPACE}/bigtosmall_join.txt

touch ${WORKSPACE}/bigtosmall_join_uniq.txt
#set +x
#IFS=$'\r\n'
#for file in `cat ${WORKSPACE}/bigtosmall_join.txt | cut -d ' ' -f 3- ` ; do
#  grep -e "^${file}$" ${WORKSPACE}/bigtosmall_join_uniq.txt > /dev/null || echo $file >> ${WORKSPACE}/bigtosmall_join_uniq.txt
#done
#set -x 
cat ${WORKSPACE}/bigtosmall_join.txt | cut -d ' ' -f 3- | /usr/bin/uniq >> ${WORKSPACE}/bigtosmall_join_uniq.txt

set +x
echo "Generate file sorted list:"
touch ${WORKSPACE}/bigtosmall_errors.txt
IFS=$'\r\n'
for file in `cat ${WORKSPACE}/bigtosmall_join_uniq.txt` ; do
	printf "."
	grep -e " ${file}$" ${WORKSPACE}/bigtosmall_join.txt >> ${WORKSPACE}/bigtosmall_sorted_size_files.txt || echo "ERROR: $file: something went wrong" >> ${WORKSPACE}/bigtosmall_errors.txt
done
printf "\n"
echo "DONE: Investigate blobs that are directly stored in idx file: ${pack_file}"
set -x

echo "START: Investigate blobs that are packed in revisions in idx file: ${pack_file}"
git verify-pack -v ${pack_file} | egrep "^\w+ blob\W+[0-9]+ [0-9]+ [0-9]+ [0-9]+" | awk -F" " '{print $1,$2,$3,$4,$5}' > ${WORKSPACE}/bigobjects_revisions.txt
join <(sort ${WORKSPACE}/bigobjects_revisions.txt) <(sort ${WORKSPACE}/allfileshas.txt) | sort -k 3 -n -r | cut -f 1,3,6- -d ' '  > ${WORKSPACE}/bigtosmall_revisions_join.txt
touch ${WORKSPACE}/bigtosmall_revisions_join_uniq.txt

#set +x
#IFS=$'\r\n'
#for file in `cat ${WORKSPACE}/bigtosmall_revisions_join.txt | cut -d ' ' -f 3- ` ; do
#  grep -e "^${file}$" ${WORKSPACE}/bigtosmall_revisions_join_uniq.txt > /dev/null || echo $file >> ${WORKSPACE}/bigtosmall_revisions_join_uniq.txt
#done
#set -x
cat ${WORKSPACE}/bigtosmall_revisions_join.txt | cut -d ' ' -f 3- | /usr/bin/uniq >> ${WORKSPACE}/bigtosmall_revisions_join_uniq.txt

set +x
echo "Generate file sorted list:"
touch ${WORKSPACE}/bigtosmall_errors_revision.txt
IFS=$'\r\n'
for file in `cat ${WORKSPACE}/bigtosmall_revisions_join_uniq.txt ` ; do
	printf "."
    grep -e " ${file}$" ${WORKSPACE}/bigtosmall_revisions_join.txt >> ${WORKSPACE}/bigtosmall_sorted_size_files_revisions.txt || echo "ERROR: $file: something went wrong" >> ${WORKSPACE}/bigtosmall_errors_revision.txt
done
printf "\n"
echo "DONE: Investigate blobs that are packed in revisions in idx file: ${pack_file}"
set -x


echo "START: Investigate if issues occured"
set +x
if [[ ! `cat ${WORKSPACE}/bigtosmall_errors.txt` == ""  ]]; then
  echo "There are errors during analyzing the files: ${WORKSPACE}/bigtosmall_errors.txt"
  ${WORKSPACE}/bigtosmall_errors.txt | uniq
fi
if [[ ! `cat ${WORKSPACE}/bigtosmall_errors_revision.txt` == ""  ]]; then
  echo "There are errors during analyzing the files: ${WORKSPACE}/bigtosmall_errors_revision.txt"
  cat ${WORKSPACE}/bigtosmall_errors_revision.txt | uniq
fi
set -x
echo "DONE: Investigate if issues occured"
