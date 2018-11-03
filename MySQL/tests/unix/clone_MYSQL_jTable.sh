export DIR=JSON/MYSQL
export MDIR=../../JSON/MYSQL
export SCHEMA=sakila
export FILENAME=sakila
export ID=1
mkdir $DIR
mysql -uroot -poracle -h192.168.1.250 -Dsys -P3306 -v -f <../../sql/JSON_IMPORT.sql
mysql -uroot -poracle -h192.168.1.250 -Dsys -P3306 -v -f --init-command="SET @SCHEMA='$SCHEMA'; SET @ID=$ID" <sql/RECREATE_SCHEMA.sql
node ../node/jTableImport --USERNAME=root --HOSTNAME=192.168.1.250 --PORT=3306 --PASSWORD=oracle --DATABASE=sys --File=$MDIR/$FILENAME.json toUser=$SCHEMA$ID
node ../node/export --USERNAME=root --HOSTNAME=192.168.1.250 --PORT=3306 --PASSWORD=oracle --DATABASE=sys --File=$DIR/$FILENAME$ID.json owner=$SCHEMA$ID
export ID=2
mysql -uroot -poracle -h192.168.1.250 -Dsys -P3306 -v -f --init-command="SET @SCHEMA='$SCHEMA'; SET @ID=$ID" <sql/RECREATE_SCHEMA.sql
node ../node/jTableImport --USERNAME=root --HOSTNAME=192.168.1.250 --PORT=3306 --PASSWORD=oracle --DATABASE=sys --File=$DIR/$FILENAME$1.json toUser=$SCHEMA$ID
node ../node/export --USERNAME=root --HOSTNAME=192.168.1.250 --PORT=3306 --PASSWORD=oracle --DATABASE=sys --File=$DIR/$FILENAME$ID.json owner=$SCHEMA$ID
dir $DIR/*1.json
dir $DIR/*2.json
