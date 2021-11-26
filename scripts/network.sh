#!/bin/bash

. scripts/fabric-ca.sh
. scripts/channel.sh
. scripts/chaincode.sh



function init_storage_volumes() {
  echo "Provisioning volume storage"

  kubectl create -f templates/k8s/pv-fabric-rms.yaml || true

  kubectl -n $NS create -f templates/k8s/pvc-fabric-rms.yaml || true

}

function load_org_config() {
  echo "Creating fabric config maps"

  kubectl -n $NS create configmap rms-config --from-file=./network/rms/config

}


function create_rms_orderer_local_MSP() {
  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name rms-orderer1 --id.secret ordererpw --id.type orderer --url https://rms-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/rms-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name rms-admin --id.secret rmsadminpw  --id.type admin   --url https://rms-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/rms-ecert-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"


  fabric-ca-client enroll --url https://rms-orderer1:ordererpw@rms-ecert-ca --csr.hosts rms-orderer1 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/rms.pharma.com/orderers/rms-orderer1.rms.pharma.com/msp
  fabric-ca-client enroll --url https://rms-admin:rmsadminpw@rms-ecert-ca --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/rms.pharma.com/users/Admin@rms.pharma.com/msp

  # Each node in the network needs a TLS registration and enrollment.
  fabric-ca-client register --id.name rms-orderer1 --id.secret ordererpw --id.type orderer --url https://rms-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  fabric-ca-client enroll --url https://rms-orderer1:ordererpw@rms-tls-ca --csr.hosts rms-orderer1 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/rms.pharma.com/orderers/rms-orderer1.rms.pharma.com/tls

  # Copy the TLS signing keys to a fixed path for convenience when starting the orderers.
  cp /var/hyperledger/fabric/organizations/ordererOrganizations/rms.pharma.com/orderers/rms-orderer1.rms.pharma.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/ordererOrganizations/rms.pharma.com/orderers/rms-orderer1.rms.pharma.com/tls/keystore/server.key

  # Create an MSP config.yaml (why is this not generated by the enrollment by fabric-ca-client?)
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/ordererOrganizations/rms.pharma.com/orderers/rms-orderer1.rms.pharma.com/msp/config.yaml


  ' | exec kubectl -n $NS exec deploy/rms-ecert-ca -i -- sh
}

function create_rms_peer_local_MSP() {

  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name rms-peer1 --id.secret peerpw --id.type peer --url https://rms-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/rms-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name rms-peer2 --id.secret peerpw --id.type peer --url https://rms-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/rms-ecert-ca/rcaadmin/msp
  fabric-ca-client register --id.name rms-peer-admin --id.secret rmsadminpw  --id.type admin   --url https://rms-ecert-ca --mspdir $FABRIC_CA_CLIENT_HOME/rms-ecert-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://rms-peer1:peerpw@rms-ecert-ca --csr.hosts rms-peer1 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/msp
  fabric-ca-client enroll --url https://rms-peer2:peerpw@rms-ecert-ca --csr.hosts rms-peer2 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer2.rms.pharma.com/msp
  fabric-ca-client enroll --url https://rms-peer-admin:rmsadminpw@rms-ecert-ca  --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/users/Admin@rms.pharma.com/msp

  # Each node in the network needs a TLS registration and enrollment.
  fabric-ca-client register --id.name rms-peer1 --id.secret peerpw --id.type peer --url https://rms-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp
  fabric-ca-client register --id.name rms-peer2 --id.secret peerpw --id.type peer --url https://rms-tls-ca --mspdir $FABRIC_CA_CLIENT_HOME/tls-ca/tlsadmin/msp

  fabric-ca-client enroll --url https://rms-peer1:peerpw@rms-tls-ca --csr.hosts rms-peer1 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/tls
  fabric-ca-client enroll --url https://rms-peer2:peerpw@rms-tls-ca --csr.hosts rms-peer2 --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer2.rms.pharma.com/tls

  # Copy the TLS signing keys to a fixed path for convenience when launching the peers
  cp /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/tls/keystore/server.key
  cp /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer2.rms.pharma.com/tls/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer2.rms.pharma.com/tls/keystore/server.key

  cp /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/users/Admin@rms.pharma.com/msp/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/users/Admin@rms.pharma.com/msp/keystore/server.key

  # Create local MSP config.yaml
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/rms-ecert-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/msp/config.yaml


  cp /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer2.rms.pharma.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/peers/rms-peer1.rms.pharma.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/rms.pharma.com/users/Admin@rms.pharma.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/rms-ecert-ca -i -- sh

}

function create_local_MSP() {
  echo "Creating local node MSP"


  create_rms_orderer_local_MSP
  create_rms_peer_local_MSP
}

function launch() {
  local yaml=$1
  cat ${yaml} \
    | sed 's,{{FABRIC_CONTAINER_REGISTRY}},'${FABRIC_CONTAINER_REGISTRY}',g' \
    | sed 's,{{FABRIC_VERSION}},'${FABRIC_VERSION}',g' \
    | kubectl -n $NS apply -f -
}

function launch_orderers() {
  echo "Launching orderers"

  launch templates/k8s/rms-orderer1.yaml

  kubectl -n $NS rollout status deploy/rms-orderer1

}

function launch_peers() {
  echo "Launching peers"

  launch templates/k8s/rms-peer1.yaml
  launch templates/k8s/rms-peer2.yaml

  kubectl -n $NS rollout status deploy/rms-peer1
  kubectl -n $NS rollout status deploy/rms-peer2

}

function deploy_network(){
  init_storage_volumes
  load_org_config

  # Network TLS CAs
  launch_TLS_CAs
  enroll_bootstrap_TLS_CA_users

  # Network ECert CAs
  register_enroll_ECert_CA_bootstrap_users
  launch_ECert_CAs
  enroll_bootstrap_ECert_CA_users

  #Create network
  create_local_MSP
  launch_orderers
  launch_peers

  #create channel
  channel_up

  #chaincode
  deploy_chaincode
  invoke_chaincode '{"Args":["check"]}'

}

