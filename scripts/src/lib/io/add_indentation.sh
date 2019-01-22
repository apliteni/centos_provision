#!/usr/bin/env bash

add_indentation(){
  sed -r "s/^/$INDENTATION_SPACES/g"
}
