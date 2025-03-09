#!/bin/bash

# Set default value of 3 if no argument is provided
if [ $# -eq 0 ]; then
  num_files=3
  echo "No argument provided, using default value of 3 files"
elif [ $# -eq 1 ]; then
  num_files=$1
else
  echo "Usage: $0 [number_of_files]"
  exit 1
fi

# Create main files
for i in $(seq 1 $num_files); do
  echo "this is file$i" >"file$i"
  echo "Created file$i"
done

# Create subdirectories with their own files
for i in $(seq 1 3); do
  mkdir -p "subdir$i"
  for j in $(seq 1 $num_files); do
    echo "this is subdir$i-file$j" >"subdir$i/subdir$i-file$j"
    echo "Created subdir$i/subdir$i-file$j"
  done
  echo "Created subdir$i with $num_files files"
done
