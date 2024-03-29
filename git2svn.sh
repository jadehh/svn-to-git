#!/bin/bash
################环境配置##################################
# 需要安装  svn  git  git-svn
##########################################################
# 项目列表list.txt 文件格式必须是unix格式 （即使用unix的换行符）
######################readme###############################
### 1 git svn等远程路径, 按照实际情况修改 ip端口，用户密码
### 2 首次运行可能需要添加主机到信任列表，请手动提前执行下面的几条命令，相应变量替换为实际内容
###   git clone ${git_url}${name}.git
###   svn mkdir --parents ${svn_url}${name}/test -m "Importing git repo ${git_url}${name}" ${svn_login}
### 3 迁移方式两种，默认git id版本方式，如果该方式不成功，则 执行脚本 ./git2svn.sh
###   更换迁移方式：需要先将本脚本之前下载的相关本地git仓库删除
### 4 可能还需要设置git邮箱 git config --global user.email "email@example.com"  git config --global user.name "Mona Lisa"

################ v 2.0 ##################################
# 只有一种迁移方式，没有脚本参数了
# 迁移方式：从git checkout每次提交的文件复制到svn本地库下，从本地库svn_repo提交
# 库名不能相同
# 增加 保留最近历史提交数的配置参数

################ v 2.1 ##################################
# 每个项目迁移前，自动删除当前文件夹下该项目的git和svn库和远程svn项目（方便重复迁移同一项目）
# 重复迁移，远程svn的提交历史会累计，请知晓
################ v 2.2 ##################################
# 修复多分支没有回到主目录bug

#####################配置修改############################
name="jadehh/svn-to-git"
githis_name="main"
svn_url="https://192.168.100.223/svn/P6-01-HG/svn-to-git"
echo "--------2.2"
# 保留最近历史提交记录的数量
max_count=10
# 保留最近【分支和版本标签】历史提交记录的数量
branch_max_count=1
#git 仓库
git_name="jadehh%40live.com"
git_psw=""
if [ -n $2 ]; then git_psw=$2
fi
echo ${git_psw}
# git服务器的ip和端口,注意结尾不要有/
git_ip="github.com"

#svn 仓库
svn_name="jiandehui"
svn_psw="test"
if [ -n $1 ]; then svn_psw=$1
fi
echo ${svn_psw}

#svn 服务器最后拼接的地址，目录默认/svn/


### 当前路径下被读取的项目列表
list_file="list.txt"
# 设置并发的进程数
thread_num=5
#####################配置修改##########################
### 最后使用的url，注意最后拼接的/，git_ip结尾不要有/
git_url="https://${git_name}:${git_psw}@${git_ip}/"
svn_login=" --username ${svn_name} --password ${svn_psw} "
####################主程序############################
echo "----git_url:${git_url}"
echo "----svn_url:${svn_url} ${svn_login}"
echo "----list_file:${list_file}"
# 路径
#DIRNAME=$0
#if [ "${DIRNAME:0:1}" = "/" ];then
#    CUR=`dirname $DIRNAME`
#else
#    CUR="`pwd`"/"`dirname $DIRNAME`"
#fi
CUR=~/code/
mkdir ${CUR}
echo "----当前路径：" $CUR
# 项目列表
starttime=$(date +%H%M%S)

#########并发 准备##########
# mkfifo
tempfifo="my_temp_fifo"
mkfifo ${tempfifo}
# 使文件描述符为非阻塞式
exec 6<>${tempfifo}
rm -f ${tempfifo}

# 为文件描述符创建占位信息
for ((i=1;i<=${thread_num};i++))
do
{
    echo
}
done >&6
#######################
 read -u6
{
      echo "----start ${name}"
      pro_name=${name##*/}
      echo $pro_name
      cd $CUR
      ###########清理文件#############
      echo "---清理文件: 清理过程错误提示可忽略" ${name}
      rm -rf ${CUR}/svn_repo/${pro_name}/源码
      rm -rf ${CUR}/${pro_name}
#      svn delete ${svn_url}/源码 ${svn_login} --message "Deleting ${svn_url}"
#      svn mkdir --parents ${svn_url}/源码 -m "创建文件夹"
      echo "---清理结束" ${name}
      mkdir ${CUR}/svn_repo/
      mkdir ${CUR}/svn_repo/${pro_name}
      BASE_DIR=$CUR
      GIT_DIR="${CUR}/${pro_name}"
      SVN_DIR="${CUR}/svn_repo/${pro_name}/源码/trunk"

      SVN_AUTH=$svn_login
      #echo "----$name 当前路径" $PWD
      git clone ${git_url}${name}.git
      cd $GIT_DIR
      #echo "----$name 当前路径" $PWD
      svn mkdir --parents ${svn_url}/源码/trunk ${svn_url}/源码/branches ${svn_url}/源码/tags -m "Importing git repo http://${git_name}@${git_ip}/${name}" ${svn_login}
      mkdir  $CUR/svn_repo/${pro_name}
      cd $CUR/svn_repo/${pro_name}
      svn co ${svn_url}/源码
#      echo "svn co ${svn_url}"
#      #############################
        function svn_checkin {
            echo '... adding files' ${pro_name}
            for file in `svn st ${SVN_DIR} | awk -F" " '{print $1 "|" $2}'`; do
                fstatus=`echo $file | cut -d"|" -f1`
                fname=`echo $file | cut -d"|" -f2`

                if [ "$fstatus" == "?" ]; then
                    if [[ "$fname" == *@* ]]; then
                        svn add $fname@;
                    else
                        svn add $fname;
                    fi
                fi
                if [ "$fstatus" == "!" ]; then
                    if [[ "$fname" == *@* ]]; then
                        svn rm $fname@;
                    else
                        svn rm $fname;
                    fi
                fi
                if [ "$fstatus" == "~" ]; then
                    rm -rf $fname;
                    svn up $fname;
                fi
            done
            echo '... finished adding files' ${pro_name}
        }

        function svn_commit {
            echo "... committing -> [$author]: $msg" ${pro_name};
            cd $SVN_DIR && svn $SVN_AUTH commit -m "[$author]: $msg" && cd $BASE_DIR;
            echo "... committed! ${pro_name}"
        }
        ##################################################
        function git2svn_start {
            for commit in `cd $GIT_DIR && git rev-list -${COMMIT_COUNT} ${githis_name} --reverse && cd $BASE_DIR`; do
            echo "...Committing $commit..." ${pro_name};
            author=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%an ${commit} && cd ${BASE_DIR}`;
            msg=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%s ${commit} && cd ${BASE_DIR}`;

            # Checkout the current commit on git
            echo '... checking out commit on Git' ${pro_name}
            cd $GIT_DIR && git checkout -f $commit && cd $BASE_DIR;

            # Delete everything from SVN and copy new files from Git
            echo '... copying files' ${pro_name}
            rm -rf $SVN_DIR/*;
            cp -prf $GIT_DIR/* $SVN_DIR/;

            # Remove Git specific files from SVN
            for ignorefile in `find ${SVN_DIR} | grep .git | grep .gitignore`;
            do
                rm -rf $ignorefile;
            done

            # Add new files to SVN and commit
            svn_checkin && svn_commit;
            echo ""
        done
        }
        ################主分支
        SVN_DIR="${CUR}/svn_repo/${pro_name}/trunk"
        COMMIT_COUNT=${max_count}
        SVN_DIR="${CUR}/svn_repo/${pro_name}/源码/trunk/"
        git2svn_start;

        ###############分支
        cd ${CUR}/${pro_name}
        branches=$(git branch -r)
        #echo "----branches ${branches}"
        branches=$(echo "${branches}" | awk -vORS=' '  '{ print $1 }' | sed 's/ $//')
        echo "----分支迁移 ${name}"
        for b_name in ${branches[@]};
        do {
            #echo "----分支名：${b_name}"
            b_short_name=${b_name##*/}
            ### 忽略 HEAD master trunk git2svn*
            if [[ "$b_short_name" != "HEAD" && "$b_short_name" != "master" && "$b_short_name" != "trunk" && "$b_short_name" != git2svn* ]]; then
                echo "----开始迁移分支：${b_name}"
                # git pull origin ${b_short_name}:${b_short_name}
                # svn mkdir --parents ${svn_url}${name}/branches/git2svn-${b_short_name} -m " import http://${git_name}@${git_ip}/${name}  分支${b_short_name}"
                cd ${CUR}/${pro_name}
                git checkout -f ${b_short_name}
                SVN_DIR="${CUR}/svn_repo/${pro_name}/源码/branches/${b_short_name}"
                COMMIT_COUNT=${branch_max_count}
                githis_name="${b_short_name}"
                mkdir --parents ${SVN_DIR}
                echo "----分支导出成功"

                git2svn_start;
            fi
        }
        done
        ###############TAG
        cd ${CUR}/${pro_name}
        branches=$(git tag -l)
        #echo "----tags ${branches}"
        branches=$(echo "${branches}" | awk -vORS=' '  '{ print $1 }' | sed 's/ $//')
        echo "----tag迁移 ${name}"
        for b_name in ${branches[@]};
        do {
            #echo "----tag名：${b_name}"
            b_short_name=${b_name}
            ### 忽略 HEAD master trunk git2svn*
            if [[ "$b_short_name" != "HEAD" && "$b_short_name" != "master" && "$b_short_name" != "trunk" && "$b_short_name" != git2svn* ]]; then
                echo "----开始迁移tag：${b_name}"
                cd ${CUR}/${pro_name}
                #svn mkdir --parents ${svn_url}${name}/tags/git2svn-tag-${b_short_name} -m " import http://${git_name}@${git_ip}/${name}  tag${b_short_name}"
                git checkout -f -b ${b_short_name} ${b_short_name}
                SVN_DIR="${CUR}/svn_repo/${pro_name}/源码/tags/${b_short_name}"
                COMMIT_COUNT=${branch_max_count}
                githis_name="${b_short_name}"
                mkdir --parents ${SVN_DIR}
                git2svn_start;
            fi
        }
        done


      ############################
      echo "----end ${name}"
        echo "" >&6
}

wait

# 关闭fd6管道
exec 6>&-

endtime=$(date +%H%M%S)

echo "全部完成"
echo -e "开始时间:\t${starttime}"
echo -e "结束时间:\t${endtime}"
