#!/bin/sh

LOG_LIMIT=100000000
SVN_DIFF="svn diff --no-diff-deleted"
SVN_LOGS="svn log -q"

get_help()
{
	echo "---------svncount ver 1.1----------"
	echo "svncount -h"
	echo "svncount -a 2014-05-22 2014-06-20 aaa bbb ccc"
	echo "svncount -u 2014-05-22 2014-06-20 aaa bbb ccc"
	echo "svncount -t 2014-05-22 2014-06-20 aaa bbb ccc"
    echo "---------by yyerdo ----------------"
}

get_all_counts()
{
	local SVN_DIR=$1
    $SVN_DIFF -r {$START_QDATE}:{$END_QDATE} $SVN_DIR | awk -v svn_dir=$SVN_DIR '
    {
        if(match($1, /^---/)) {}
        else if(match($1, "//")) {}
        else if(match($1, /\+\+\+/)) {}
        else {
            if(match($1, "^+")) {
                if(NR == (del_nr + 1)) {
                	all_mod++;
                	all_del--;
                }
                else all_add++;
            }
            else if(match($1, "^-")) {
                del_nr = NR;
                all_del++;
            }
        }
    }
    END {
       all_add = 0 + all_add;
       all_mod = 0 + all_mod;
       all_del = 0 + all_del;

       printf " %-10s %-10s %-10s %-10s %-20s \n", all_add+all_mod, all_add, all_mod, all_del, svn_dir;
    }'
}

get_user_counts()
{
	local SVN_DIR=$1

	$SVN_LOGS -l $LOG_LIMIT -q -r {$START_QDATE}:{$END_QDATE} $SVN_DIR | awk -v svn_dir=$SVN_DIR '
    /^r/{
        username = $3;
		tmpdiff[username] = sprintf("%s.%s.tmpdiff", svn_dir, username);

        rlog = gensub("r", "", 1, $1);
		cmd_svndiff = sprintf("svn diff --no-diff-deleted -c %s %s >> %s", rlog, svn_dir, tmpdiff[username]);
        
        system(cmd_svndiff)
	}
    END {
        for(key in tmpdiff) {
            cmd_rm = sprintf("rm %s", tmpdiff[key]);

            while(getline line < tmpdiff[key]) {
                all_nr++;
                if(match(line, /^---/)) {}
                else if(match(line, "//")) {}
                else if(match(line, /\+\+\+/)) {}
                else {
                    if(match(line, "^+")) {
                        if(all_nr == (del_nr + 1)) {
                            all_mod++;
                            all_del--;
                        }
                        else all_add++;
                    }
                    else if(match(line, "^-")) {
                        del_nr = all_nr;
                        all_del++;
                    }
                }
            }

            all_add = 0 + all_add;
            all_mod = 0 + all_mod;
            all_del = 0 + all_del;

            system(cmd_rm);
            printf " %-10s %-10s %-10s %-10s %-12s %-12s \n", all_add+all_mod, all_add, all_mod, all_del, key, svn_dir;
        }
    }' 
}

get_type_counts()
{
	local SVN_DIR=$1

    $SVN_DIFF -r {$START_QDATE}:{$END_QDATE} $SVN_DIR | awk -v svn_dir=$SVN_DIR '
    {
        if($1=="+++") {
            last_index = split($2, filename, "/");
            last_index = split(filename[last_index], filetype, ".");
            if (last_index > 1) {
                ftype = filetype[last_index];
            }
            else ftype="other";
        }
        else if(match($1, "^---")) {}
        else if(match($1, "//")) {}
        else {
            if(match($1, "^+")) {
                if(NR == (del_nr + 1)) {
                	fcounts[ftype, "mod"]++;
                	fcounts[ftype, "del"]--;
                }
                else fcounts[ftype, "add"]++;
            }
            else if(match($1, "^-")) {
                del_nr = NR;
                fcounts[ftype, "del"]++;
            }
        }
    }
    END {
        for(key in fcounts) {
            split(key, subkey, SUBSEP);

            all_add = 0 + fcounts[subkey[1], "add"];
            all_mod = 0 + fcounts[subkey[1], "mod"];
            all_del = 0 + fcounts[subkey[1], "del"];

            printf " %-10s %-10s %-10s %-10s %-12s %-12s \n", all_add+all_mod, all_add, all_mod, all_del, subkey[1], svn_dir;
        }
    }' | awk '!a[$5]++'

}

get_date_area()
{
	START_QDATE=$1
 	END_QDATE=$2
}

while [ -n "$1" ]; do
	case $1 in
		-h) shift
			get_help;
			break;;

		-u) shift
			get_date_area $1 $2;shift 2;
			echo
			echo "------------------------------------------------------------------"
			echo "Code Line Statistics"
			echo date from $START_QDATE to $END_QDATE
			echo "please waiting ...."
			echo "------------------------------------------------------------------"
            		awk 'BEGIN{printf " %-10s %-10s %-10s %-10s %-12s %-12s \n", "TATAL", "NEW", "MOD", "DEL", "USER", "DIR";}'
			echo "------------------------------------------------------------------"
			for x in "$@"; do
					SVN_DIR=$x
					svn update $SVN_DIR > /dev/null
					get_user_counts $SVN_DIR
            		echo "------------------------------------------------------------------"
			done
			break;;

		-t) shift
			get_date_area $1 $2;shift 2;
			echo
			echo "------------------------------------------------------------------"
			echo "Code Line Statistics"
			echo date from $START_QDATE to $END_QDATE
			echo "please waiting ...."
			echo "------------------------------------------------------------------"
            		awk 'BEGIN{printf " %-10s %-10s %-10s %-10s %-12s %-12s \n", "TATAL", "NEW", "MOD", "DEL", "TYPE", "DIR";}'
			echo "------------------------------------------------------------------"
			for x in "$@"; do
					SVN_DIR=$x
					svn update $SVN_DIR > /dev/null
					get_type_counts $SVN_DIR
	        	echo "------------------------------------------------------------------"
			done
			break;;

		-a) shift
			get_date_area $1 $2;shift 2;
			echo
			echo "-------------------------------------------------------------------"
			echo "Code Line Statistics"
			echo date from $START_QDATE to $END_QDATE
			echo "please waiting ...."
			echo "-------------------------------------------------------------------"
            		awk 'BEGIN{printf " %-10s %-10s %-10s %-10s %-12s \n", "TATAL", "NEW", "MOD", "DEL", "DIR";}'
			echo "-------------------------------------------------------------------"
			for x in "$@"; do
					SVN_DIR=$x
					svn update $SVN_DIR > /dev/null
					get_all_counts $SVN_DIR
            		echo "------------------------------------------------------------------"
			done
			break;;
	esac
done
