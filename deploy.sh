#!/bin/bash
export LANG=en_US

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# remove public contents
rm -rf public/*

# Build the project.
hugo # if using a theme, replace with `hugo -t <YOURTHEME>`

# Go To Public folder
cd public
# Add changes to git.
git config user.name windyboy
git config user.email windyboy@gmail.com
git add .

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg" -v

# Push source and build repos.
git push origin master

# Come Back up to the Project Root
cd ..
