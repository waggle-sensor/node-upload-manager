# Node Upload Agent

The upload agent is responsible for moving the data plugins have staged locally to beehive.

The high level architecture looks like:

```txt
  ┌─────────────────────────────────────────────────────────────┐
 ┌─────────────────────────────────────────────────────────────┐│
┌─────────────────────────────────────────────────────────────┐││
│ On each compute device                                      │││
│                                                             │││
│                      upload key (secret)                    │││
│                              V                              │││
│           mount  ┌───────────────────┐   rsync to beehive   │││
│ /uploads ------> │ Node Upload Agent │ ---------------------->
│                  └───────────────────┘                      │┘
└─────────────────────────────────────────────────────────────┘
```

## Usage

This services expects the following things:

1. A directory `/uploads` must be mounted with RW access. Items of the form `/uploads/x/y` will be moved to beehive.
2. An ssh key located at `/auth/ssh-key` for the remote ssh server.
