#!/bin/bash

# This script starts Kstars then Ekos with the default profile.
# If Kstars is already running, the script will monitor it.
# If an Ekos scheduler job file named default.esl exists in the
# home directory, the telescope is unparked and the scheduler
# job file will be loaded and started.
# If Kstars is closed or crashes, the script will restart it
# automatically.

SCHEDFILE=/home/astronaut/default.esl	# Can be a link to a .esl file located elsewhere or a real file
LOGFILE=/dev/null
# LOGFILE=/home/astronaut/kstars.log
echo $'\n\n\n\n\n' >> $LOGFILE
date >> $LOGFILE

# Setup X

export DISPLAY=:0
XAUTHORITY=`ls /tmp/xauth_* -tr | tail -n1`
xhost +local: >> $LOGFILE 2>&1

# Main loop

while true
do
	while true
	do
		if qdbus org.kde.kstars >> /dev/null 2>&1
		then
			break
		else
			/usr/bin/kstars >> $LOGFILE 2>&1 &
		fi
		echo ">>> Waiting for Kstars to start..." | tee -a $LOGFILE
		sleep 1
	done

	echo ">>> Kstars started successfully." | tee -a $LOGFILE

	CNT=1
	while true
	do
		qdbus org.kde.kstars /KStars/Ekos org.kde.kstars.Ekos.start >> $LOGFILE 2>&1 && break
		sleep 1
		echo ">>> Waiting for ekos availability : attempt "$CNT" of 10..." | tee -a $LOGFILE
		CNT=$((CNT+1))
		if (( CNT > 10 ))
		then
			echo ">>> Too many attempts to start ekos, aborting..." | tee -a $LOGFILE
			break
		fi
	done
	sleep 1

	# Show main Ekos window
	qdbus org.kde.kstars /kstars/MainWindow_1/actions/show_ekos trigger

	# At this point, INDI devices are up and running

	# Check if the default scheduler script exists
	if [ -f $SCHEDFILE ]
	then
		echo ">>> $SCHEDFILE found, unparking telescope and starting scheduler job." | tee -a $LOGFILE
		# Unpark telescope
		qdbus org.kde.kstars /kstars/MainWindow_1/actions/telescope_unpark org.qtproject.Qt.QAction.trigger

		# (Re-)start scheduler jobs
		# => load and start scheduler file
		qdbus org.kde.kstars /KStars/Ekos/Scheduler loadScheduler $SCHEDFILE >> $LOGFILE 2>&1
		qdbus org.kde.kstars /KStars/Ekos/Scheduler start >> $LOGFILE 2>&1
	fi

	# Watchdog loop, restart everything if Kstars crashes or is closed
	echo ">>> Starting watchdog loop..." | tee -a $LOGFILE
	while true
	do
		qdbus org.kde.kstars /KStars/Ekos > /dev/null 2>&1 || break
		sleep 1
	done
	echo ">>> Kstars has been closed or crashed, restarting in 5 seconds..." | tee -a $LOGFILE
	sleep 5
done
