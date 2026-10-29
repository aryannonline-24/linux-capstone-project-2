#!/bin/bash
# Linux Capstone Project 2 - Aryan Kumar
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
usage() { echo "Usage: $0 {start|stop|restart|status}"; }
if [ "$#" -ne 1 ]; then usage; exit 1; fi
case "$1" in
    start|stop|restart)
        if [ "$(id -u)" -ne 0 ]; then
            echo "Use sudo for service changes." >&2
            exit 2
        fi
        if [ "$1" != stop ]; then nginx -t || exit 1; fi
        echo "Requested Nginx action: $1"
        systemctl "$1" nginx || exit 1
        if [ "$1" = stop ]; then
            if systemctl is-active --quiet nginx; then
                echo "Nginx is unexpectedly still running"; exit 1
            fi
            echo "Nginx stopped successfully"
        elif systemctl is-active --quiet nginx; then
            echo "Nginx $1 completed successfully"
        else
            echo "Nginx is not running after $1"; exit 1
        fi
        ;;
    status) systemctl status nginx --no-pager ;;
    *) echo "Invalid action: $1"; usage; exit 1 ;;
esac
