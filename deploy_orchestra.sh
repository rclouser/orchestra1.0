ORCHESTRA_SRC_BUCKET='gs://orchestra-practice-tools-245512/*'

echo "Please provide the following:"
read -p "Please enter name for the composer environment: " COMPOSER_NAME
read -p "Please enter composer location: " COMPOSER_LOCATION
read -p "Please enter composer zone: " COMPOSER_ZONE
read -p "Please enter partner id(s) comma seperated: " PARTNER_STRING

if [ -z "$" ]
then
      echo "\$COMPOSER_NAME is empty"
      exit 1
fi

if [ -z "$COMPOSER_LOCATION" ]
then
      echo "\$COMPOSER_LOCATION is empty"
      exit 1
fi

if [ -z "$COMPOSER_ZONE" ]
then
      echo "\$COMPOSER_ZONE is empty"
      exit 1
fi

if [ -z "$PARTNER_STRING" ]
then
      echo "\$PARTNER_STRING is empty"
      exit 1
fi

PROJECT=$GOOGLE_CLOUD_PROJECT
PROJECT_ID=$(gcloud projects list --filter="$GOOGLE_CLOUD_PROJECT" --format="value(PROJECT_NUMBER)")

##convert string to array
IFS=', ' read -r -a PARTNER_IDS <<< "$PARTNER_STRING"
PARTNER_COUNT=${#PARTNER_IDS[@]}


echo "Name: $COMPOSER_NAME"
echo "Location: $COMPOSER_LOCATION"
echo "Zone: $COMPOSER_ZONE"
echo "Partner IDs: $PARTNER_STRING"
echo "Number of Partner IDs: $PARTNER_COUNT"

echo "The deployment will start with the above configuration."

read -p "Do you agree to proceed? Type 'Y' or 'y' if you agree: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

echo "Enabling APIs..."
gcloud services enable composer.googleapis.com

echo "$(date)-Building Composer Environment. This can take approximately 20 minutes..."
gcloud composer environments create $COMPOSER_NAME \
    --location $COMPOSER_LOCATION \
    --zone $COMPOSER_ZONE \
    --machine-type n1-standard-2 \
    --python-version 2 \



COMPOSER_DAG_LOCATION=`gcloud composer environments describe $COMPOSER_NAME   --location $COMPOSER_LOCATION  --format="get(config.dagGcsPrefix)"`
COMPOSER_BUCKET=`dirname $COMPOSER_DAG_LOCATION`

echo "Composer Bucket: $COMPOSER_BUCKET"
echo "Dag Folder: $COMPOSER_DAG_LOCATION"


echo "$(date)-Creating BigQuery Datasets"
BQ_SDF_DATASET=${COMPOSER_NAME//[-]/_}'_sdf'
BQ_ERF_DATASET=${COMPOSER_NAME//[-]/_}'_erf'
echo "SDF dataset: $BQ_SDF_DATASET"
echo "ERF dataset: $BQ_ERF_DATASET"

bq --location=$COMPOSER_LOCATION mk --dataset $BQ_SDF_DATASET
bq --location=$COMPOSER_LOCATION mk --dataset $BQ_ERF_DATASET

echo "$(date)-Creating custom orchestra variables in  Airflow ..."
ERF_DAG_NAME=${COMPOSER_NAME//[-]/_}'_sequential_erf_dag'
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s sdf_bq_dataset $BQ_SDF_DATASET
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s erf_bq_dataset $BQ_ERF_DATASET
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s gce_zone $COMPOSER_LOCATION
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s gcs_bucket ${COMPOSER_BUCKET//'gs://'}
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s cloud_project_id $PROJECT_ID
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s partner_ids $PARTNER_STRING
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s number_of_advertisers_per_sdf_api_call $PARTNER_COUNT
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --s sequential_erf_dag_name $ERF_DAG_NAME

echo "$(date)-Copying Orchestra repo from $ORCHESTRA_SRC_BUCKET to $COMPOSER_BUCKET ..."
gsutil -m cp -r $ORCHESTRA_SRC_BUCKET $COMPOSER_BUCKET

echo "$(date)-Creating standard orchestra variables in Airflow from orchestra_vars.json...."
gcloud composer environments run $COMPOSER_NAME --location=$COMPOSER_LOCATION variables -- --i /home/airflow/gcs/data/orchestra_vars.json

echo "$(date)-Composer and Orchestra setup complete"
