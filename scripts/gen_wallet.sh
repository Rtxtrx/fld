#!/bin/bash -eE

# Alex  2021-09-10 23:29:00


echo

function show_usage(){
echo
echo " Use: ./gen_wallet.sh <Wallet name> <'Safe' or 'SetCode'> <Num of custodians> <workchain>"
echo " All fields required!"
echo "<Wallet Name> - name of wallet." 
echo "<'Safe' or 'SetCode'> - SafeCode or SetCode multisig wallet"
echo "<num of custodians> must greater 0 or less 32"
echo "<workchain> - workchain to deploy wallet. '0' or '-1' "
echo
echo "if you have file '<Wallet name>_1.keys.json' with seed phrase in this dir - it will used to generate address"
echo "if you have such files (..._2..., ..._3... etc) for each custodian, it will use for key pairs generation respectively"
echo
echo " Example: ./gen_wallet Safe 5 0"
echo
exit 1
}

[[ $# -lt 3 ]] && show_usage

CodeOfWallet=$2
if [[ ! $CodeOfWallet == "Safe" ]] && [[ ! $CodeOfWallet == "SetCode" ]];then
    echo "###-ERROR(line $LINENO): Wrong code of wallet. Choose 'Safe' or 'SetCode'"
    show_usage
    exit 1
fi
CUSTODIANS=$3
if [[ $CUSTODIANS -lt 1 ]] || [[ $CUSTODIANS -gt 32 ]];then
    echo "###-ERROR(line $LINENO): Wrong Num of custodians must be >= 1 and <= 31"  
    show_usage
    exit 1
fi
WorkChain="$4"
if [[ ! "$WorkChain" == "0" ]] && [[ ! "$WorkChain" == "-1" ]];then
    echo "###-ERROR(line $LINENO): Wrong workchain. Choose '0' or '-1'"
    show_usage
    exit 1
fi

SCRIPT_DIR=`cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P`
#source "${SCRIPT_DIR}/env.sh"
#source "${SCRIPT_DIR}/functions.shinc"

WAL_NAME=$1
CONTRACTS_DIR="$HOME/Contracts"
KEY_FILES_DIR="$HOME/fld_wallet/MSKeys_${WAL_NAME}"
export CALL_TC="$HOME/bin/tonos-cli -c $SCRIPT_DIR/tonos-cli.conf.json"
export Marvin_Addr="0:deda155da7c518f57cb664be70b9042ed54a92542769735dfb73d3eef85acdaf"
export Marvin_ABI="$CONTRACT_DIR/Marvin.abi.json"




[[ ! -d $KEY_FILES_DIR ]] && mkdir $KEY_FILES_DIR

Wallet_Code=${CONTRACTS_DIR}/SafeMultisigWallet.tvc
Wallet_ABI=${CONTRACTS_DIR}/SafeMultisigWallet.abi.json
if [[ "$CodeOfWallet" == "SetCode" ]];then
    Wallet_Code=${CONTRACTS_DIR}/SetcodeMultisigWallet.tvc
    Wallet_ABI=${CONTRACTS_DIR}/SetcodeMultisigWallet.abi.json
fi
if [[ ! -f $Wallet_Code ]] || [[ ! -f $Wallet_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI. Check contracts folder."  
    show_usage
    exit 1
fi
echo "Wallet Code: $Wallet_Code"
echo "ABI for wallet: $Wallet_ABI"

#=======================================================================================
# generation cycle
for (( i=1; i <= $((CUSTODIANS)); i++ ))
do
    echo "$i"
    
    # generate or read seed phrases
    [[ ! -f ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt ]] && SeedPhrase=`$CALL_TC genphrase | grep "Seed phrase:" | cut -d' ' -f3-14 | tee ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt`
    [[ -f ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt ]] && SeedPhrase=`cat ${KEY_FILES_DIR}/${WAL_NAME}_seed_${i}.txt`
    SeedPhrase=$(echo $SeedPhrase | tr -d '"')
    
    # generate public key
    PubKey=`$CALL_TC genpubkey "$SeedPhrase" | tee ${KEY_FILES_DIR}/${WAL_NAME}_PubKeyCard_${i}.txt | grep "Public key:" | awk '{print $3}' | tee ${KEY_FILES_DIR}/${WAL_NAME}_pub_${i}_.key`
    echo "PubKey${i}: $PubKey"
    
    # generate pub/sec keypair file
    $CALL_TC getkeypair "${KEY_FILES_DIR}/${WAL_NAME}_${i}.keys.json" "$SeedPhrase" &> /dev/null
done

cp -f "${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json" "${KEY_FILES_DIR}/${WAL_NAME}.keys.json"

#=======================================================================================
# generate multisignature wallet address
WalletAddress=`$CALL_TC genaddr $Wallet_Code $Wallet_ABI \
		--setkey "${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json" \
        --wc "$WorkChain" \
		| tee  ${KEY_FILES_DIR}/${WAL_NAME}_addr-card.txt \
		| grep "Raw address:" | awk '{print $3}' \
		| tee ${KEY_FILES_DIR}/${WAL_NAME}.addr`

echo
echo "All files saved in $KEY_FILES_DIR"
echo
echo "Wallet Address: $WalletAddress"

if [[ ! -f ${KEYS_DIR}/${WAL_NAME}.addr ]];then
    [[ ! -f "${KEYS_DIR}/${WAL_NAME}.addr" ]] && cp "${KEY_FILES_DIR}/${WAL_NAME}.addr" ${KEYS_DIR}/
    [[ ! -f "${KEYS_DIR}/${WAL_NAME}.keys.json" ]] && cp "${KEY_FILES_DIR}/${WAL_NAME}.keys.json" ${KEYS_DIR}/
    for (( i=1; i <= $((CUSTODIANS)); i++ ))
    do
        [[ ! -f "${KEYS_DIR}/${WAL_NAME}_${i}.keys.json" ]] && cp "${KEY_FILES_DIR}/${WAL_NAME}_${i}.keys.json" ${KEYS_DIR}/
    done
    echo "MSIG files ${WAL_NAME}.addr & ${WAL_NAME}_*.keys.json copied to ${KEYS_DIR}/"
fi
echo "If you want to replace exist wallet, you need to delete all files in ${KEY_FILES_DIR}/ and ${WAL_NAME}.addr & ${WAL_NAME}_*.keys.json in ${KEYS_DIR}/ folder"
echo
echo "To deploy wallet, send tokens to it address and use MS-Wallet_deploy.sh script"
echo
echo -e "${BoldText}${RedBack} Save all seed phrases!! ${NormText} from '${WAL_NAME}_seed_*.txt' files in ${KEY_FILES_DIR}/"
echo
#========================Give token from Marvin========================
# Check Marvin ABI
if [[ ! -f $Marvin_ABI ]];then
    echo "###-ERROR(line $LINENO): Can not find Wallet code or ABI. Check contracts folder."  
    exit 1
fi

DST_NAME=${KEYS_DIR}/${WAL_NAME}.addr
DST_KEY_FILE="$${KEY_FILES_DIR}/${WAL_NAME}_1.keys.json"

DST_ACCOUNT=`cat ${KEYS_DIR}/${DST_NAME}.addr`
if [[ -z $DST_ACCOUNT ]];then
    echo "###-ERROR(line $LINENO): Can't find SRC address! ${KEYS_DIR}/${DST_NAME}.addr"
    exit 1
fi
msig_public=`cat $DST_KEY_FILE | jq ".public"`
msig_secret=`cat $DST_KEY_FILE | jq ".secret"`
if [[ -z $msig_public ]] || [[ -z $msig_secret ]];then
    echo "###-ERROR(line $LINENO): Can't find public and/or secret key in ${DST_KEY_FILE}!"
    exit 1
fi

$CALL_TC call "$Marvin_Addr" grant "{\"addr\":\"$DST_ACCOUNT\"}" --abi "${Marvin_ABI}"

exit 0


exit 0