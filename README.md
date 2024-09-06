# 🤖 Voice Cloning
- Users upload the audio records and clone the voice for given text.
- Learning, having fun and hands-on experience with AWS & Terraform & Serverless architecture.

## 🌐 Resources

| Resource | Link |
|---|---|
| Web via Cloudfront | https://dzpqh0mwojrs9.cloudfront.net/ |
| Web via S3 | http://voicecloning-website.s3-website.eu-central-1.amazonaws.com/ |
| API via Cloudfront | http://d20hbh58zkqtxv.cloudfront.net/ |
| API via APIGateway | https://l481bschml.execute-api.eu-central-1.amazonaws.com/api |


## 🚀 Tech Stack

### 1. Architecture

![Architecture.png](Architecture.png)

### 2. AWS

- Install AWS CLI
- Create a developer user with `AdministratorAccess` to be used by TF
- Configure the ` ~/.aws/credentials` file for the credentials

### 3. Terraform

**1. How to deploy?**

```bash
chmod +x 'scripts/provision_the_project.sh' && ./scripts/provision_the_project.sh
```

**2. How to destroy?**
```bash
brew install cloud-nuke
cloud-nuke aws --region eu-central-1
chmod +x './scripts/force_delete_s3.sh' && ./scripts/force_delete_s3.sh
```

### 4. App

```bash
# Local setup
conda create --name VoiceCloning python=3.10 -y
conda activate VoiceCloning
pip install --upgrade pip
pip install -r requirements.txt
python entrypoint.py
```

### 5. API
```bash
# Local setup
cd api
conda activate VoiceCloning
pip install -r requirements.txt
uvicorn main:app --reload

# TODO: Move this to api/main.py via boto3:
aws batch submit-job \
  --job-name "demo-$(uuidgen | tr -d '-')" \
  --job-queue batch-fargate-voicecloning-job-queue \
  --job-definition aws-batch-job-definition-for-fargate-for-voicecloning \
  --container-overrides '{"environment":[{"name":"PROJECT_ID","value":"730540022af3402482dddc7180204fbc"}]}'
```

## 🛠️ Notes
- Search on `HARDCODED` on the code base and replace them accordingly.
- If the Cloudfront seems outdated, introduce "Invalidations" with a path:
  ```bash
  # website
  aws cloudfront create-invalidation --distribution-id "E281IVOBPB39H5" --paths "/*"
  # api
  aws cloudfront create-invalidation --distribution-id "EZ0ZFJOIKT14T" --paths "/*"
  ```
- Future: Remove the hardcoded variables in the code base and replace them with environment variables.
- The model is forked and adapted from https://github.com/jnordberg/tortoise-tts.
  * However, this should be changed to main repo https://github.com/neonbjb/tortoise-tts.

<br>

## 👨🏻‍💻 Developer
- Furkan M. Torun | Researcher and Data Scientist
- Website: [furkanmtorun.github.io](https://furkanmtorun.github.io)
- LinkedIn: [@furkanmtorun](https://www.linkedin.com/in/furkanmtorun)
- Twitter: [@furkanmtorun](https://www.twitter.com/furkanmtorun)
- Mail: [furkanmtorun[at]gmail[dot]com](mailto:furkanmtorun@gmail.com) 
- Academics: [Google Scholar Profile](https://scholar.google.com/citations?user=d5ZyOZ4AAAAJ) 

Moreover, please do not hesitate to comment via opening an issue via GitHub if you have any suggestions or feedback!
