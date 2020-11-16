# Node Upload Manager

This service is responsible for uploading the data plugins have staged locally.

The high level architecture looks like:

```txt
┌─────────────────────────────────────────────────────────────┐
│ On each compute device                                      │
│                                                             │
│                      upload key (secret)                    │
│                              V                              │
│           mount  ┌─────────────────────┐ rsync to beehive   │
│ /uploads ------> │ Node Upload Manager │ -------------------│->
│                  └─────────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```
