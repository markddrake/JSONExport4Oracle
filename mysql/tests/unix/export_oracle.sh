export TGT=$1
export USRID=$2
export VER=$3
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --PORT=$DB_PORT --DATABASE=$DB_DBASE --File=$TGT/HR$VER.json --owner=HR$USRID$
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --PORT=$DB_PORT --DATABASE=$DB_DBASE --File=$TGT/SH$VER.json --owner=SH$USRID$
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --PORT=$DB_PORT --DATABASE=$DB_DBASE --File=$TGT/OE$VER.json --owner=OE$USRID$
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --PORT=$DB_PORT --DATABASE=$DB_DBASE --File=$TGT/PM$VER.json --owner=PM$USRID$
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --PORT=$DB_PORT --DATABASE=$DB_DBASE --File=$TGT/IX$VER.json --owner=IX$USRID$
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --PORT=$DB_PORT --DATABASE=$DB_DBASE --File=$TGT/BI$VER.json --owner=BI$USRID$