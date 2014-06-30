#!/bin/sh
#
# uwsgi          Start/Stop the uwsgi protocol daemon.
#
# chkconfig: 2345 90 60
# description: uwsgi 
# http://projects.unbit.it/uwsgi/





# Check if binary exists. Without binary you can't manage the service.
# If binary doesn't exist, run the code in {...} part.
# if first argument is "status", exit code is 4, else exit code is 6
[ -f /usr/local/bin/uwsgi ] || {
    [ "$1" = "status" ] && exit 4 || exit 6
}

#Last command return value.
RETVAL=0
prog="uwsgi"
# path to binary executable
exec=/usr/local/bin/uwsgi
# File lock
lockfile=/tmp/uwsgi_pid.txt
# Config location
config=/etc/sysconfig/uwsgi

# Source function library. All variables in 'functions' script will replaced all current variables in existing shell, until script is completed
# http://ss64.com/bash/source.html
. /etc/rc.d/init.d/functions

# user is root, file /etc/sysconfig/$prog exists, read source from /etc/sysconfig/$prog
# [ $UID -eq 0 ] && [ -e /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog

start() {
    # allow root and UID=500 user to run init script
    if [ $UID -ne 0 || $UID -ne 500 ] ; then
        echo "User has insufficient privilege."
        exit 4
    fi
    # can execute binary
    [ -x $exec ] || exit 5
    # config exists
    [ -f $config ] || exit 6
    echo -n $"Starting $prog: "
    #run $prog with '--ini $config' arguments
    daemon $prog --ini $config
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
}

stop() {
    if [ $UID -ne 0 ] ; then
        echo "User has insufficient privilege."
        exit 4
    fi
    
    echo -n $"Stopping $prog: "
        if [ -n "`pidfileofproc $exec`" ]; then
                killproc $exec
                RETVAL=3
        else
                failure $"Stopping $prog"
        fi
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
}

restart() {
    rh_status_q && stop
    start
}

reload() {
        echo -n $"Reloading $prog: "
        if [ -n "`pidfileofproc $exec`" ]; then
                killproc $exec -HUP
        else
                failure $"Reloading $prog"
        fi
        retval=$?
        echo
}

force_reload() {
        # new configuration takes effect after restart
    restart
}

rh_status() {
    # run checks to determine if the service is running or use generic status
    status -p /var/run/crond.pid $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}


case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
        restart
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload}"
        exit 2
esac
exit $?
