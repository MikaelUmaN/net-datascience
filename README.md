# net-datascience
Data Science image for dotnet

## Build
docker build -t mikaeluman/net-datascience .

## Run
docker run -p 8888:8888 -v ${PWD}:/home/jovyan/work mikaeluman/net-datascience

