#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##move  call
export ENV_ADDR=0x9d6f2e34e937842df89642cd96fba8509d4e47d297f716ce3a44df3070a79851
export PACKAGE=0xf6e84c774436ed4dbc9d0a0071a6b5d59c8b6d9f7a76356b8dc3b6c4f6e96b5e
export ADMIN_CAP=0x45f7813d6656f19a5bb04ac22e43225628d72bb97db7604b4cfcc3ab76bde2a7
export NEW_ADMIN=0xedf3e379faa087566e22467fc10de73920fe4ec2a73cac30ab85653409545f14

sui client call --gas-budget 200000000 --package $PACKAGE --module "config" --function "change_admin" --args  $ADMIN_CAP $NEW_ADMIN
