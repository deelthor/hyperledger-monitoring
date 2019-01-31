# hyperledger-fabric-monitoring

```sh
./startFabricOnMinikube.sh
# create, fetch, join Channel
PEER_POD=$(kubectl get pods -n peers -l "app=hlf-peer,release=peer1" -o jsonpath="{.items[0].metadata.name}")
kubectl exec -n peers $PEER_POD -- peer channel create -o ord1-hlf-ord.orderers.svc.cluster.local:7050 -c mychannel -f /hl_config/channel/mychannel.tx
kubectl exec -n peers $PEER_POD -- peer channel fetch config /var/hyperledger/mychannel.block -c mychannel -o ord1-hlf-ord.orderers.svc.cluster.local:7050
kubectl exec -n peers $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH peer channel join -b /var/hyperledger/mychannel.block'
kubectl exec -n peers $PEER_POD -- peer channel list
# port forwarding to prometheus server
kubectl port-forward -n monitoring svc/prom-prometheus-operator-prometheus 9090:9090
open http://localhost:9090/targets
```
