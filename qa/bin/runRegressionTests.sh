# Run from YADAMU_HOME
source $(dirname "${BASH_SOURCE[0]}")/export.sh
source $(dirname "${BASH_SOURCE[0]}")/$YADMU_TESTNAME
.sh
source $(dirname "${BASH_SOURCE[0]}")/fileRoundtrip.sh
source $(dirname "${BASH_SOURCE[0]}")/dbRoundtrip.sh
source $(dirname "${BASH_SOURCE[0]}")/mongoImport.sh
source $(dirname "${BASH_SOURCE[0]}")/mongoRoundtrip.sh
source $(dirname "${BASH_SOURCE[0]}")/lostConnection.sh
