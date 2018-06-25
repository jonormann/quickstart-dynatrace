#!/bin/bash -e

echo "The script can be used to resize lvm volume. Use it if EBS size is larger than the initial snapshot size."
echo "This assumes that the device names has not been changed."
echo
echo "WARNING: THERE IS A RISK OF DATA LOSS"
echo
echo -n "Are you sure you want to proceed? [y]es / [n]o"
echo
read line

if [[ "$line" -eq "Y" || "$line" -eq "Yes" ]]
then
        lsblk

        pvresize /dev/xvdb
        lvresize /dev/vgbin/lvbin -l "100%VG" -r

        pvresize /dev/xvdc
        lvresize /dev/vgmisc/lvmisc -l "100%VG" -r
		
		pvresize /dev/xvdd
        lvresize /dev/vgsrv/lvsrv -l "100%VG" -r
		
		pvresize /dev/xvde
        lvresize /dev/vgcas/lvcas -l "100%VG" -r
		
		pvresize /dev/xvdf
        lvresize /dev/vgelastic/lvelastic -l "100%VG" -r

        echo "Done"
else
        echo "Aborted"
fi

