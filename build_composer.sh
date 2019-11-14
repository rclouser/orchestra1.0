echo "Before starting deployment, we need some information:"
read -p "Please enter name for the composer environment: " COMPOSER_NAME
read -p "Please enter composer location: " COMPOSER_LOCATION
read -p "Please enter composer zone: " COMPOSER_ZONE

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


PROJECT=$GOOGLE_CLOUD_PROJECT
PROJECT_ID=$(gcloud projects list --filter="$GOOGLE_CLOUD_PROJECT" --format="value(PROJECT_NUMBER)")
REGION=$(gcloud -q config get-value compute/region)
APP_ENGINE_REGION=$(echo $REGION | sed -e 's/\([0-9]\)*$//g')


echo "Name: $COMPOSER_NAME"
echo "Location: $COMPOSER_LOCATION"
echo "Zone: $COMPOSER_ZONE"

echo "The deployment will start with the above configuration."

read -p "Do you agree to proceed? Type 'Y' or 'y' if you agree: " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

echo "Deployment starting..."

echo "Enabling APIs..."
gcloud services enable composer.googleapis.com


gcloud composer environments create $COMPOSER_NAME \
    --location $COMPOSER_LOCATION \
    --zone $COMPOSER_ZONE \
    --machine-type n1-standard-2 \
    --python-version 2 \
