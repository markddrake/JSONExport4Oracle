# Run from YADAMU_HOME
export YADAMU_HOME=`pwd`
export YADAMU_QA_HOME=$YADAMU_HOME/qa
export YADAMU_TASK=import
source $YADAMU_HOME/app/install/bin/installYadamu.sh
source $YADAMU_QA_HOME/install/bin/installYadamu.sh
unset YADAMU_LOG_PATH
export YADAMU_LOG_ROOT=$YADAMU_HOME/log
source $YADAMU_QA_HOME/bin/initializeLogging.sh $YADAMU_TEST
if [ -z ${NODE_NO_WARNINGS+x} ]; then export NODE_NO_WARNINGS=1; fi
node $YADAMU_HOME/app/YADAMU_QA/common/node/test.js CONFIG=$YADAMU_QA_HOME/regression/$YADAMU_TASK.json >$YADAMU_LOG_PATH/$YADAMU_TASK.log