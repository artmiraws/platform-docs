# Evidence

Reproducible commands that show what the platform actually deployed. They are better than
screenshots: anyone can run them and get the same picture.

## Everything in an application's namespace

```bash
kubectl get $(kubectl api-resources --verbs=list --namespaced -o name \
  | grep -v 'endpoints' | tr '\n' ',' | sed 's/,$//') \
  -n todolist --no-headers 2>/dev/null \
  | awk '{print $1}' | grep '/' | cut -d'/' -f1 | sort | uniq -c | sort -nr
```

```text
6 replicaset.apps
3 pod
2 serviceaccount
2 podmetrics.metrics.k8s.io
2 configmap
1 targetgroupbinding.elbv2.k8s.aws
1 service
1 secret
1 role.rbac.authorization.k8s.io
1 rolebinding.rbac.authorization.k8s.io
1 poddisruptionbudget.policy
1 job.batch
1 ingress.networking.k8s.io
1 horizontalpodautoscaler.autoscaling
1 externalsecret.external-secrets.io
1 deployment.apps
1 cronjob.batch
```

The set is exactly the chart's objects plus the controller-owned ones (`targetgroupbinding`,
`podmetrics`) — one owner per object.

## Cluster and workloads

```bash
kubectl get nodes -o wide
kubectl -n todolist get pods,deploy,hpa,pdb,ingress,externalsecret
kubectl -n todolist get externalsecret todolist -o jsonpath='{.status.conditions[*].message}'
```

## GitOps

```bash
kubectl -n argocd get applications
kubectl -n argocd get application todolist -o jsonpath='{.status.sync.status} {.status.health.status}'
```

## Platform (AWS)

```bash
# The contract an application reads
aws ssm get-parameters-by-path --path /platform/dev --recursive \
  --query 'Parameters[].{name:Name,value:Value}' --output table

# Clusters, node groups, databases, load balancers
aws eks list-clusters
aws rds describe-db-clusters --query 'DBClusters[].{id:DBClusterIdentifier,status:Status}'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
```

## End to end

```bash
curl -fsS https://dev.todolist.nexusauto.com.br/healthz   # ok
curl -fsS https://prod.todolist.nexusauto.com.br/healthz  # ok
curl -fsS https://docs.nexusauto.com.br/ | head -1
```
