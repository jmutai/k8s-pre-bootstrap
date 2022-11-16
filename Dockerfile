FROM python:3.10-alpine

WORKDIR /ansible

RUN python3 -m pip install ansible

COPY . .

CMD [ "ansible-playbook", "k8s_setup.yml" ]
