minikube start --memory=4096 --bootstrapper=kubeadm
# minikube bug
# otherwise pods wont be able to reach their own service via
minikube ssh
sudo ip link set docker0 promisc on
exit
helm init
kubectl create ns orderers
kubectl create ns peers
# Prometheus Operator incl Prometheus, Grafana, ServierMonitor etc.
helm install stable/prometheus-operator --name prom --namespace monitoring
cd config
# save relevant Orderer admin crypto-config files as secrets
MSP_DIR=./crypto-config/ordererOrganizations/orderers.svc.cluster.local/users/Admin@orderers.svc.cluster.local/msp
ORG_CERT=$(ls ${MSP_DIR}/admincerts/*.pem)
kubectl create secret generic -n orderers hlf--ord-admincert --from-file=cert.pem=$ORG_CERT
CA_CERT=$(ls ${MSP_DIR}/cacerts/*.pem)
kubectl create secret generic -n orderers hlf--ord-cacert --from-file=cacert.pem=$CA_CERT
# save Peer admin crypto-config files as secrets
MSP_DIR=./crypto-config/peerOrganizations/peers.svc.cluster.local/users/Admin@peers.svc.cluster.local/msp
ORG_CERT=$(ls ${MSP_DIR}/admincerts/*.pem)
kubectl create secret generic -n peers hlf--peer-admincert --from-file=cert.pem=$ORG_CERT
ORG_KEY=$(ls ${MSP_DIR}/keystore/*_sk)
kubectl create secret generic -n peers hlf--peer-adminkey --from-file=key.pem=$ORG_KEY
CA_CERT=$(ls ${MSP_DIR}/cacerts/*.pem)
kubectl create secret generic -n peers hlf--peer-cacert --from-file=cacert.pem=$CA_CERT
# save Orderer genesis as secret
kubectl create secret generic -n orderers hlf--genesis --from-file=genesis.block
# save Channel tx as secret
kubectl create secret generic -n peers hlf--channel --from-file=mychannel.tx
# save Orderer node identity cryptographic material as secrets
MSP_DIR=./crypto-config/ordererOrganizations/orderers.svc.cluster.local/orderers/ord1-hlf-ord.orderers.svc.cluster.local/msp
NODE_CERT=$(ls ${MSP_DIR}/signcerts/*.pem)
kubectl create secret generic -n orderers hlf--ord1-idcert --from-file=cert.pem=$NODE_CERT
NODE_KEY=$(ls ${MSP_DIR}/keystore/*_sk)
kubectl create secret generic -n orderers hlf--ord1-idkey --from-file=key.pem=$NODE_KEY
# install Orderer
helm install ../hlf-ord -n ord1 --namespace orderers
ORD_POD=$(kubectl get pods -n orderers -l "app=hlf-ord,release=ord1" -o jsonpath="{.items[0].metadata.name}")
until (kubectl logs -n orderers $ORD_POD | grep 'Starting orderer'); do
  echo 'Waiting for Orderer to start'
  sleep 5
done
# install CouchDB
helm install ../hlf-couchdb -n cdb-peer1 --namespace peers
CDB_POD=$(kubectl get pods -n peers -l "app=hlf-couchdb,release=cdb-peer1" -o jsonpath="{.items[*].metadata.name}")
until (kubectl logs -n peers $CDB_POD | grep 'Apache CouchDB has started on'); do
  echo 'Waiting for CouchDB to start'
  sleep 5
done
# save Peer node identity cryptographic material as secrets
MSP_DIR=./crypto-config/peerOrganizations/peers.svc.cluster.local/peers/peer1-hlf-peer.peers.svc.cluster.local/msp
NODE_CERT=$(ls ${MSP_DIR}/signcerts/*.pem)
kubectl create secret generic -n peers hlf--peer1-idcert --from-file=cert.pem=$NODE_CERT
NODE_KEY=$(ls ${MSP_DIR}/keystore/*_sk)
kubectl create secret generic -n peers hlf--peer1-idkey --from-file=key.pem=$NODE_KEY
# install Peer
helm install ../hlf-peer -n peer1 --namespace peers
PEER_POD=$(kubectl get pods -n peers -l "app=hlf-peer,release=peer1" -o jsonpath="{.items[0].metadata.name}")
until (kubectl logs -n peers $PEER_POD | grep 'Starting peer'); do
  echo 'Waiting for Peer to start'
  sleep 5
done
# create, fetch, join Channel
kubectl exec -n peers $PEER_POD -- peer channel create -o ord1-hlf-ord.orderers.svc.cluster.local:7050 -c mychannel -f /hl_config/channel/mychannel.tx
kubectl exec -n peers $PEER_POD -- peer channel fetch config /var/hyperledger/mychannel.block -c mychannel -o ord1-hlf-ord.orderers.svc.cluster.local:7050
kubectl exec -n peers $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH peer channel join -b /var/hyperledger/mychannel.block'
kubectl exec -n peers $PEER_POD -- peer channel list
