#!/usr/bin/bash -e

# Definition des commandes
CMD_BASENAME="/usr/bin/basename"
CMD_SNMPWALK="/usr/bin/snmpwalk"
CMD_CUT="/usr/bin/cut"

# Lecture et affectation des couleurs
NORMAL="\\033[0;39m"
VERT="\\033[1;32m"

SCRIPTNAME=`$CMD_BASENAME $0`

# Version
VERSION="0.1"

# Options par defaut
export HOST="";
export SNMP_VERSION="2c";
export SNMP_COMMUNITY="public";
export BS_NUMBER="";
export TYPE="STATUS";
export MESSAGE=""

#+-------------------------------------------------------------------------------+
#                        Gestion du status dans Centreon
#+-------------------------------------------------------------------------------+

export STATUS_OK=0
export STATUS_WARNING=1
export STATUS_CRITICAL=2
export STATUS_UNKNOWN=3

#+-------------------------------------------------------------------------------+
#                            Fonctions de base
#+-------------------------------------------------------------------------------+

function usage(){
cat << EOF

+-------------------------------------------------------------------------------+
                        Centreon ARCHEAN Monitoring
+-------------------------------------------------------------------------------+

usage: $0 options

$0 [--help]  --host <Hostname/IP> --snmp-version <2c> --snmp-community <public> --type <STATUS, VALUE> --oid <OID>

OPTIONS:
   --help			show this message
   --host			Host Name or IP
   --snmp-version		SNMP Version (Default 2c)
   --snmp-community		SNMP Community (Default public)
		For SNMP V3 :
			--snmp-username : 	Security name
			--authpassphrase :	Authentication protocol pass phrase.
			--authprotocol :	Authentication protocol: MD5|SHA.
			--privpassphrase :	Privacy protocol pass phrase
			--privprotocol :	Privacy protocol: DES|AES
			--securityengineid : Security engine ID

   --type	(STATUS, VALUE)
   --metric	 (°C, %, ...)
   --warning	Warning
   --critical	Critical
   --oid   	OID value to check (numeric format only).

EOF
exit 1
}


Check_Status(){
	Status=$1
	Message=$2
	Result=$3
	case $Result in
		0)
			echo "OK : Aucune Alarme -> "$Message;
			exit $STATUS_OK;
		;;
		1)
			echo "WARNING : "$Message;
			exit $STATUS_WARNING;
		;;
		2)
			echo "CRITICAL : "$Message;
			exit $STATUS_CRITICAL;
		;;
		3)
			echo "UNKNOWN : Le snmp ne repond pas";
			exit $STATUS_UNKNOWN;
		;;
		*)
			echo "UNKNOWN : Reponse SNMP non conforme";
			exit $STATUS_UNKNOWN;
        ;;
	esac
}

Decimale(){
	Valeur=$1
	Coefficient=$2
	export ENTIER=$(($Valeur/$Coefficient))
	Reste=$(($Valeur-$(($ENTIER*$Coefficient))))
	export TEMPERATURE=$(echo $ENTIER"."$Reste)
}

Check_Value(){
	Value=$1
	# Decimale $Value 10
	Message=$2
	Rc=$3
	echo $Message$Value$METRIC"|Temp="$Value
	exit $Rc
}


Check_Indicateur(){
	$SNMP_COMMAND > /dev/null 2>&1
	Rc=$?
	if [ $Rc -gt 0 ]
	then
		echo -e "snmpwalk: Erreur " $HOST
		exit $Rc
	fi
	Result=$($SNMP_COMMAND 2> /dev/null| cut -d" " -f4)
	# if [ $TYPE=="STATUS" ]
	# then
		# if [ $Result=="End of MIB" ]
		# then
			# Result=3
		# fi
	# fi
	Ctiticite=0
	Result=""
	case $OID in
		".1.3.6.1.2.1.1.5.0")
			# Controle du sysname SNMPv2-MIB::sysName.0  
			Result=$($SNMP_COMMAND|cut -d" " -f4| sed "s/\"//g")
			# if [ -z "$Result" ]
			# then
			case $Result in
			""|"X.X")
				echo "CRITICAL : Disfonctionnement du service";
				exit $STATUS_CRITICAL ;
			;;
			*)
				echo "OK : connectivité SNMP OK de l'hôte "$Result
				exit $STATUS_OK
			;;
			esac
		;;
		".1.3.6.1.4.1.33815.1.2.1.2.2.2.1.2.1")
			#export INDICATEUR="ARCHEAN-STATUS-MIB::paDeviceCnxDefect";$
			Result=$($SNMP_COMMAND|cut -d" " -f4)
			case $Result 
			in
				1)
					Criticite=$STATUS_CRITICAL;
				;;
				0)
					Criticite=$STATUS_OK;
				;;
				*)
					Criticite=$STATUS_UNKNOWN;
				;;
			esac
			#Check_Status $Result "Defaut de connexion." $Criticite;
			Check_Status $Result "Perte de communication entre l'ATCONT et la matrice." $Criticite;
		;;
		".1.3.6.1.4.1.33815.1.2.1.2.2.2.1.4.1")
			#export INDICATEUR="ARCHEAN-STATUS-MIB::paDeviceInputsDefectsSynthesis";
			Result=$($SNMP_COMMAND|cut -d" " -f4)
			case $Result 
			in
				1)
					Criticite=$STATUS_CRITICAL;
				;;
				0)
					Criticite=$STATUS_OK;
				;;
				*)
					Criticite=$STATUS_UNKNOWN;
				;;
			esac
			#Check_Status $Result "Defaut de synthèse lié aux 'Entrées Matrice'." $Criticite;
			Check_Status $Result "Au moins un pupitre de sécurité est en défaut." $Criticite;
		;;
		".1.3.6.1.4.1.33815.1.2.1.2.2.2.1.5.1")
                        #export INDICATEUR="ARCHEAN-STATUS-MIB::paDeviceOutputsDefectsSynthesis";
                        Result=$($SNMP_COMMAND|cut -d" " -f4)
                        case $Result
                        in
                                1)
                                        Criticite=$STATUS_CRITICAL;
                                ;;
                                0)
                                        Criticite=$STATUS_OK;
                                ;;
                                *)
                                        Criticite=$STATUS_UNKNOWN;
                                ;;
                        esac
                 #       Check_Status $Result "Defaut de synthèse lié aux 'Sorties Matrice'." $Criticite;
			Check_Status $Result "Au moins un amplificateur ou une ligne HP est en défaut." $Criticite;
                ;;
               ".1.3.6.1.4.1.33815.1.2.1.2.3.1.0")
                        #export INDICATEUR="ARCHEAN-STATUS-MIB::externalFaultSynthesis";
                        Result=$($SNMP_COMMAND|cut -d" " -f4)
                        case $Result
                        in
                                1)
                                        Criticite=$STATUS_CRITICAL;
                                ;;
                                0)
                                        Criticite=$STATUS_OK;
                                ;;
                                *)
                                        Criticite=$STATUS_UNKNOWN;
                                ;;
                        esac
                #        Check_Status $Result "Defaut de synthèse 'Externe'." $Criticite;
			Check_Status $Result "Synthèse défaut des défauts liaison SSI, CANBUS, Moxa, liaison Modan, EAE,AES externe etc…" $Criticite;
                ;;
               ".1.3.6.1.4.1.33815.1.2.1.2.1.0")
                        #export INDICATEUR="ARCHEAN-STATUS-MIB::systemDefectsSynthesis";
                        Result=$($SNMP_COMMAND|cut -d" " -f4)
                        case $Result
                        in
                                1)
                                        Criticite=$STATUS_CRITICAL;
                                ;;
                                0)
                                        Criticite=$STATUS_OK;
                                ;;
                                *)
                                        Criticite=$STATUS_UNKNOWN;
                                ;;
                        esac
                #        Check_Status $Result "Defaut de synthèse." $Criticite;
			Check_Status $Result "Au moins un défaut est présent sur le système." $Criticite;
                ;;
		*)
			echo " OID "$OID" not use"
			usage;
		;;
	esac

}


while [ $# -gt 0 ]
do
	case $1 in
		-h|--help)
		usage;
		;;
        -H|--host)
			export HOST=$(echo $2 | sed "s/'//g");
			shift;
        ;;
        -V|--snmp-version)
			export SNMP_VERSION=$(echo $2 | sed "s/'//g");
			shift;
        ;;
        -C|--snmp-community)
			export SNMP_COMMUNITY=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--snmp-username)
			export SNMP_USERNAME=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--authpassphrase)
			export AUTHPASSPHRASE=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--authprotocol)
			export AUTHPROTOCOL=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--privpassphrase)
			export PRIVPASSPHRASE=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--privprotocol)
			export PRIVPROTOCOL=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--securityengineid)
			export SECURITYENGINEID=$(echo $2 | sed "s/'//g");
			shift;
	;;
        --type)
			export TYPE=$(echo $2 | sed "s/'//g");
			shift;
	;;
        --metric)
			export METRIC=$(echo $2 | sed "s/'//g");
			shift;
	;;
        --alarm)
			export ALARM=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--warning)
			export WARNING=$(echo $2 | sed "s/'//g");
			shift;
	;;
        --critical)
			export CRITICAL=$(echo $2 | sed "s/'//g");
			shift;
	;;
	--oid)
			export OID=$(echo $2 | sed "s/'//g");
			shift;
	;;
        (*)
			break;
        ;;
		(--) 
			shift; 
			break;
		;;
		(-*) 
			echo -e "$0: error - unrecognized option $1\n" 1>&2; 
			exit 1;
		;;
    esac
	shift
 done

#+-------------------------------------------------------------------------------+
#                    Controle de la validite des arguments
#+-------------------------------------------------------------------------------+

 if [ -z $OID ] 
then
	echo "OID need \n\n";
	usage;
 fi
 
 if [ -z $HOST ] 
then
	echo "HOST need \n\n";
	usage;
 fi

 case $SNMP_VERSION in
	2c|2)
		export SNMP_COMMAND="snmpwalk -v 2c -c $SNMP_COMMUNITY $HOST $OID -t 10";
	;;
	3)
		if [ -z $SNMP_USERNAME ] || [ -z $AUTHPASSPHRASE ] || [ -z $AUTHPROTOCOL ] || [ -z $PRIVPASSPHRASE ] || [ -z $PRIVPROTOCOL ]
		then
			echo " Cannot connect to SNMP V3, Args need \n\n";
			usage;
		fi
		export SNMP_COMMAND="snmpwalk -v 3 -u "$SNMP_USERNAME" -l authPriv -a "$AUTHPROTOCOL" -A "$AUTHPASSPHRASE" -x "$PRIVPROTOCOL" -X "$PRIVPASSPHRASE" "$HOST" "$OID" -t 10" ;
	;;
esac
 
#+-------------------------------------------------------------------------------+
#                    Controle de la validite des argument
#+-------------------------------------------------------------------------------+
Check_Indicateur
