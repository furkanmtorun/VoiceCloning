FROM public.ecr.aws/lambda/python:3.10

WORKDIR ${LAMBDA_TASK_ROOT}

COPY . .

RUN python -m pip install --no-cache-dir -r requirements.txt

CMD ["main.handler"]
