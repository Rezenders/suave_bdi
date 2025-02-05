# suave_bdi

## Download docker image

```bash
docker pull rezenders/suave_bdi
```

## Build docker image

On linux:
```bash
docker build --platform linux/amd64--tag suave_bdi .
```

On Mac:
```bash
docker build --platform linux/arm64--tag suave_bdi .
```

## Run docker image

```bash
docker run -p 6080:80 --security-opt seccomp=unconfined --shm-size=512m suave_bdi
```

## Test SUAVE installation

Inside a terminal in the docker container:

```bash
cd ~/suave_ws/src/suave/runner
./example_run.sh
```

Wait for a while, if the robot starts moving, it worked. The GUI is very slow since gpu is not used.
