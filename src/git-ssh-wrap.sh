#!/bin/bash

exec ssh -o "StrictHostKeyChecking no" -i ./data/id_rsa $1 $2
