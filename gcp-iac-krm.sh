#!/bin/bash
#
# Copyright 2019-2021 Shiyghan Navti. Email shiyghan@techequity.company
#
#################################################################################
####    Implement CloudSQL Instance using Config Connector on Kubernetes    #####
#################################################################################

function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

mkdir -p `pwd`/gcp-iac-krm > /dev/null 2>&1
export PROJDIR=`pwd`/gcp-iac-krm
export SCRIPTNAME=gcp-iac-krm.sh

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=europe-west2
export GCP_ZONE=europe-west2-a
export GCP_CLUSTER=gcp-gke-cluster
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
================================================
Configure Config Connector   
------------------------------------------------
Please enter number to select your choice:
 (1) Enable APIs
 (2) Configure Kubernetes cluster
 (3) Configure service accounts and secrets
 (4) Configure Config Connector
 (5) Configure database
 (G) Launch user guide
 (Q) Quit
-----------------------------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
       fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_CLUSTER=$GCP_CLUSTER
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_ZONE=$GCP_ZONE
export GCP_CLUSTER=$GCP_CLUSTER
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo "*** Google Cloud zone is $GCP_ZONE ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable sql-component.googleapis.com sqladmin.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    echo
    echo "$ gcloud services enable sql-component.googleapis.com sqladmin.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable sql-component.googleapis.com sqladmin.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"
    echo
    echo "$ gcloud beta container clusters create \$GCP_CLUSTER --zone \$GCP_ZONE --machine-type e2-standard-4 --num-nodes 4 --spot # to create container cluster" | pv -qL 100
    echo      
    echo "$ gcloud container clusters get-credentials \$GCP_CLUSTER --zone \$GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    echo
    echo "$ kubectl create namespace cnrm-system # create a namespace" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    export GCP_PROJECT=$(gcloud config list --format 'value(core.project)') > /dev/null 2>&1 
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type e2-standard-4 --num-nodes 4 --spot # to create container cluster" | pv -qL 100
    gcloud beta container clusters create $GCP_CLUSTER --zone $GCP_ZONE --machine-type e2-standard-4 --num-nodes 4 --spot
    echo      
    echo "$ gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE # to retrieve the credentials for cluster" | pv -qL 100
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
    echo
    echo "$ kubectl create namespace cnrm-system # create config management system namespace" | pv -qL 100
    kubectl create namespace cnrm-system
    echo
    echo "$ kubectl create namespace $GCP_PROJECT # to create GCP_PROJECT id namespace" | pv -qL 100
    kubectl create namespace $GCP_PROJECT 
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    export GCP_PROJECT=$(gcloud config list --format 'value(core.project)') > /dev/null 2>&1 
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE  # to delete cluster" | pv -qL 100
    gcloud beta container clusters delete $GCP_CLUSTER --zone $GCP_ZONE
else
    export STEP="${STEP},2i"   
    echo
    echo "1. Create container cluster" | pv -qL 100
    echo "2. Retrieve the credentials for cluster" | pv -qL 100
    echo "3. Enable current user to set RBAC rules" | pv -qL 100
    echo "4. Create config management system namespace" | pv -qL 100
    echo "5. Create GCP_PROJECT id namespace" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo      
    echo "$ gcloud iam service-accounts create cnrm-system # to create system service account" | pv -qL 100
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member serviceAccount:cnrm-system@\${GCP_PROJECT}.iam.gserviceaccount.com --role roles/owner # to bind owner role to system service account" | pv -qL 100
    echo
    echo "$ gcloud iam service-accounts keys create --iam-account cnrm-system@\$GCP_PROJECT.iam.gserviceaccount.com \$PROJDIR/key.json # to download the JSON key associated with the service account" | pv -qL 100
    echo
    echo "$ kubectl create secret generic gcp-key --from-file \$PROJDIR/key.json --namespace cnrm-system # to register key as a secret" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud iam service-accounts create cnrm-system # to create system service account" | pv -qL 100
    gcloud iam service-accounts create cnrm-system
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:cnrm-system@$GCP_PROJECT.iam.gserviceaccount.com --role roles/owner # to bind owner role to system service account" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:cnrm-system@$GCP_PROJECT.iam.gserviceaccount.com --role roles/owner
    echo
    echo "$ gcloud iam service-accounts keys create --iam-account cnrm-system@$GCP_PROJECT.iam.gserviceaccount.com $PROJDIR/key.json # to download the JSON key associated with the service account" | pv -qL 100
    gcloud iam service-accounts keys create --iam-account cnrm-system@$GCP_PROJECT.iam.gserviceaccount.com $PROJDIR/key.json
    echo
    kubectl delete secret gcp-key > /dev/null 2>&1 
    echo "$ kubectl create secret generic gcp-key --from-file $PROJDIR/key.json --namespace cnrm-system # to register key as a secret" | pv -qL 100
    kubectl create secret generic gcp-key --from-file $PROJDIR/key.json --namespace cnrm-system
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    echo
    echo "$ gcloud iam service-accounts delete cnrm-system@$GCP_PROJECT.iam.gserviceaccount.com # to delete service account" | pv -qL 100
    gcloud iam service-accounts delete cnrm-system@$GCP_PROJECT.iam.gserviceaccount.com
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Create system service account" | pv -qL 100
    echo "2. Bind owner role to system service account" | pv -qL 100
    echo "3. Download the JSON key associated with the service account" | pv -qL 100
    echo "4. Register key as a secret" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"        
    echo
    echo "$ gsutil cp gs://cnrm/latest/release-bundle.tar.gz release-bundle.tar.gz # to download the Config Connector YAML files" | pv -qL 100
    echo
    echo "$ tar zxvf release-bundle.tar.gz # to uncompress and extract the Config Connector YAML files" | pv -qL 100
    echo      
    echo "$ kubectl apply -f install-bundle-gcp-identity/ # to apply config connector yaml" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"  
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo
    cd $PROJDIR
    echo "$ gsutil cp gs://cnrm/latest/release-bundle.tar.gz release-bundle.tar.gz # to download the Config Connector YAML files package" | pv -qL 100
    gsutil cp gs://cnrm/latest/release-bundle.tar.gz release-bundle.tar.gz
    echo
    echo "$ tar zxvf release-bundle.tar.gz # to uncompress and extract the Config Connector YAML files" | pv -qL 100
    tar zxvf release-bundle.tar.gz
    echo      
    echo "$ kubectl apply -f install-bundle-gcp-identity/ # to apply config connector yaml" | pv -qL 100
    kubectl apply -f install-bundle-gcp-identity/
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"  
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1 
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1 
    echo      
    echo "$ kubectl delete -f $PROJDIR/install-bundle-gcp-identity/ # to delete config connector yaml" | pv -qL 100
    kubectl delete -f $PROJDIR/install-bundle-gcp-identity/
    echo
    echo "$ rm -rf $PROJDIR/install-bundle-gcp-identity # to delete Config Connector YAML files" | pv -qL 100
    rm -rf $PROJDIR/install-bundle-gcp-identity
else
    export STEP="${STEP},4i"   
    echo
    echo "1. Download the Config Connector YAML files package" | pv -qL 100
    echo "2. Uncompress and extract the Config Connector YAML files" | pv -qL 100
    echo "3. Apply config connector yaml" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"5")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},5i"
    echo
    echo "$ kubectl apply --namespace \$GCP_PROJECT -f - <<EOF
    apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLInstance
metadata:
  name: \$GCP_PROJECT
spec:
  databaseVersion: MYSQL_5_7
  region: us-central1
  settings:
    tier: db-f1-micro    
EOF" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT get sqlinstance # to get sql instances" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT describe sqlinstance \$GCP_PROJECT # to describe sql instance" | pv -qL 100
    echo
    echo "$ kubectl apply --namespace \$GCP_PROJECT -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cfgconn-sqlsecret
data:
  password: cGFzc3dvcmQ=
EOF" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT get secret # to get secrets" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT describe secret cfgconn-sqlsecret # to describe secret" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLUser
metadata:
  name: cfgconn-sqluser
spec:
  instanceRef:
    name: \$GCP_PROJECT
  host: \"%\"
  password:
    valueFrom:
      secretKeyRef:
        name: cfgconn-sqlsecret
        key: password
EOF" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT get sqlusers # to get sql users" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT describe sqlusers cfgconn-sqluser # to describe sql user" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT apply -f - <<EOF
    apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLDatabase
metadata:
  labels:
    label-one: \"cfgconn-costcenter\"
  name: cfgconn-sqldatabase
spec:
  charset: utf8mb4
  collation: utf8mb4_bin
  instanceRef:
    name:\$GCP_PROJECT
EOF" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT get sqldatabase # to get sql databases" | pv -qL 100
    echo
    echo "$ kubectl --namespace \$GCP_PROJECT describe sqldatabase cfgconn-sqldatabase # to describe sql database" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},5"
    export GCP_PROJECT=$(gcloud config list --format 'value(core.project)') > /dev/null 2>&1 
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLInstance
metadata:
  name: $GCP_PROJECT
spec:
  databaseVersion: MYSQL_5_7
  region: us-central1
  settings:
    tier: db-f1-micro    
EOF" | pv -qL 100
kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLInstance
metadata:
  name: $GCP_PROJECT
spec:
  databaseVersion: MYSQL_5_7
  region: us-central1
  settings:
    tier: db-f1-micro    
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT get sqlinstance # to get sql instances" | pv -qL 100
    kubectl --namespace $GCP_PROJECT get sqlinstance
    echo
    echo "$ kubectl --namespace $GCP_PROJECT describe sqlinstance $GCP_PROJECT # to describe sql instance" | pv -qL 100
    kubectl --namespace $GCP_PROJECT describe sqlinstance $GCP_PROJECT
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cfgconn-sqlsecret
data:
  password: cGFzc3dvcmQ=
EOF" | pv -qL 100
kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cfgconn-sqlsecret
data:
  password: cGFzc3dvcmQ=
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT get secret # to get secrets" | pv -qL 100
    kubectl --namespace $GCP_PROJECT get secret
    echo
    echo "$ kubectl --namespace $GCP_PROJECT describe secret cfgconn-sqlsecret # to describe secret" | pv -qL 100
    kubectl --namespace $GCP_PROJECT describe secret cfgconn-sqlsecret
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLUser
metadata:
  name: cfgconn-sqluser
spec:
  instanceRef:
    name: $GCP_PROJECT
  host: \"%\"
  password:
    valueFrom:
      secretKeyRef:
        name: cfgconn-sqlsecret
        key: password
EOF" | pv -qL 100
kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLUser
metadata:
  name: cfgconn-sqluser
spec:
  instanceRef:
    name: $GCP_PROJECT
  host: "%"
  password:
    valueFrom:
      secretKeyRef:
        name: cfgconn-sqlsecret
        key: password
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT get sqlusers # to get sql users" | pv -qL 100
    kubectl --namespace $GCP_PROJECT get sqlusers
    echo
    echo "$ kubectl --namespace $GCP_PROJECT describe sqlusers cfgconn-sqluser # to describe sql user" | pv -qL 100
    kubectl --namespace $GCP_PROJECT describe sqlusers cfgconn-sqluser 
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLDatabase
metadata:
  labels:
    label-one: "cfgconn-costcenter"
  name: cfgconn-sqldatabase
spec:
  charset: utf8mb4
  collation: utf8mb4_bin
  instanceRef:
    name: $GCP_PROJECT
EOF" | pv -qL 100
kubectl --namespace $GCP_PROJECT apply -f - <<EOF
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLDatabase
metadata:
  labels:
    label-one: "cfgconn-costcenter"
  name: cfgconn-sqldatabase
spec:
  charset: utf8mb4
  collation: utf8mb4_bin
  instanceRef:
    name: $GCP_PROJECT
EOF
    echo
    read -n 1 -s -r -p $'*** Press the Enter key to continue ***'
    echo && echo
    echo "$ kubectl --namespace $GCP_PROJECT get sqldatabase # to get sql databases" | pv -qL 100
    kubectl --namespace $GCP_PROJECT get sqldatabase
    echo
    echo "$ kubectl --namespace $GCP_PROJECT describe sqldatabase cfgconn-sqldatabase # to describe sql database" | pv -qL 100
    kubectl --namespace $GCP_PROJECT describe sqldatabase cfgconn-sqldatabase
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},5x"
    export GCP_PROJECT=$(gcloud config list --format 'value(core.project)') > /dev/null 2>&1 
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    gcloud config set compute/zone $GCP_ZONE > /dev/null 2>&1
    gcloud container clusters get-credentials $GCP_CLUSTER --zone $GCP_ZONE > /dev/null 2>&1
    echo
    echo "$ kubectl --namespace $GCP_PROJECT delete sqldatabase cfgconn-sqldatabase # to delete sql database" | pv -qL 100
    kubectl --namespace $GCP_PROJECT delete sqldatabase cfgconn-sqldatabase
    echo
    echo "$ kubectl --namespace $GCP_PROJECT delete sqlusers cfgconn-sqluser # to delete sql user" | pv -qL 100
    kubectl --namespace $GCP_PROJECT delete sqlusers cfgconn-sqluser 
    echo
    echo "$ kubectl --namespace $GCP_PROJECT delete secret cfgconn-sqlsecret # to delete secret" | pv -qL 100
    kubectl --namespace $GCP_PROJECT delete secret cfgconn-sqlsecret
    echo
    echo "$ kubectl --namespace $GCP_PROJECT delete sqlinstance $GCP_PROJECT # to delete sql instance" | pv -qL 100
    kubectl --namespace $GCP_PROJECT delete sqlinstance $GCP_PROJECT
else
    export STEP="${STEP},5i"   
    echo
    echo "1. Configure Cloud SQL instance" | pv -qL 100
    echo "2. Configure Cloud SQL user" | pv -qL 100
    echo "3. Configure Cloud SQL user password" | pv -qL 100
    echo "4. Configure Cloud SQL database" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;
 
"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
