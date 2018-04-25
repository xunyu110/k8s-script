#!/bin/bash

PROJECT=''
REPLICAS=''

DB_USER=''
DB_PASSWORD=''
CEPH_SECRET=''
CEPH_MONITORS=''
STORAGE=''
IMAGE=''
PGPOOL_REPLICAS=''
POOL_USERS=''
REPLICA_USER=''
POOL_PCP_USER=''
REPLICA_PASSWORD=''
POOL_PCP_PASSWORD=''


function usage() {
    echo "run.sh help info
    -p project_name, set project name;
    -r replica, set replica counts;
    -u username, set db user name;
    -w password, set db password;
    -s storage, set pv storage;
    -f ceph_path, set ceph path;
    -m monitors, set ceph monitor hosts;
    -h , show help info;"
}

function create_namespace() {
    echo "---
apiVersion: v1
kind: Namespace
metadata:
  name: \"$PROJECT\"" >> ./$PROJECT/namespace.yaml
}

function create_configs() {
    n=0
    temp=''
    while [ $n -lt $REPLICAS ]
    do
        if [ $n == 0 ]
        then
            temp="$n:$PROJECT-db-node-$n.$PROJECT::::"
        else
            temp="$temp,$n:$PROJECT-db-node-$n.$PROJECT::::"
        fi
        n=$(( n+1 ))
    done

    echo "---
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: $PROJECT
  name: $PROJECT-config
  labels:
    app: $PROJECT
data:
  app.db.database: \"$PROJECT.$PROJECT\"
  app.db.cluster.name: \""$PROJECT"_cluster\"
  app.db.cluster.replication.db: \"replica_db\"
  app.db.pool.backends: \"$temp\"
---
apiVersion: v1
kind: Secret
metadata:
  namespace: $PROJECT
  name: $PROJECT-secret
type: Opaque
data:
  app.db.user: \"$DB_USER\" #wide
  app.db.password: \"$DB_PASSWORD\" #pass
  app.db.cluster.replication.user: \"$REPLICA_USER\" #replica_user
  app.db.cluster.replication.password: \"$REPLICA_PASSWORD\" #replica_pass
  app.db.pool.users: \"$POOL_USERS\" #wide:pass
  app.db.pool.pcp.user: \"$POOL_PCP_USER\" #pcp_user
  app.db.pool.pcp.password: \"$POOL_PCP_PASSWORD\" #pcp_pass%" >> $PROJECT/configs.yaml

}

function create_pv() {
    n=0
    temp=''
    while [ $n -lt $REPLICAS ]
    do
        echo "---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: db-data-$PROJECT-db-node-$n
  labels:
    system: $PROJECT-db
    node: node-$n
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: $STORAGE
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /Users/hawick/pgdata-$n
  #cephfs:
  #  monitors: $MONITORS
  #  path: $CEPH_PATH
  #  user: $PROJECT
  #  secretRef: $CEPH_SECRET
" >> $PROJECT/pv.yaml

        n=$(( n+1 ))
    done

}

function create_pvc() {
    n=0
    while [ $n -lt $REPLICAS ]
    do
        echo "---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-data-$PROJECT-db-node-$n
  namespace: $PROJECT
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: $STORAGE
  selector:
    matchLabels:
      system: $PROJECT-db
      node: node-$n
" >> $PROJECT/pvc.yaml

        n=$(( n+1 ))
    done

}

function create_services() {
    echo "
apiVersion: v1
kind: Service
metadata:
  namespace: $PROJECT
  name: $PROJECT-db
  labels:
    name: database
    system: $PROJECT
spec:
  clusterIP: None
  ports:
    - port: 5432
      targetPort: 5432
  selector:
    name: database
    system: $PROJECT" >> $PROJECT/service.yaml
}

function create_nodes() {
    n=0
    nodes=''
    while [ $n -lt $REPLICAS ]
    do
        if [ $n == 0 ]
        then
            nodes="$PROJECT-db-node-$n.$PROJECT-db"
        else
            nodes="$nodes,$PROJECT-db-node-$n.$PROJECT-db"
        fi
        n=$(( n+1 ))
    done
    echo "
apiVersion: apps/v1
kind: StatefulSet
metadata:
  namespace: $PROJECT
  name: $PROJECT-db-node
  labels:
    name: database
    system: $PROJECT
    app: $PROJECT
spec:
  replicas: $REPLICAS
  serviceName: \"$PROJECT-db\"
  selector:
    matchLabels:
      system: $PROJECT
  template:
    metadata:
      labels:
        name: database
        system: $PROJECT
    spec:
      containers:
        - name: db-node
          image: hawickhuang/ha-postgresql:10
          livenessProbe:
            exec:
              command: ['bash', '-c', '/usr/local/bin/cluster/healthcheck/is_major_master.sh']
            initialDelaySeconds: 600
            timeoutSeconds: 10
            periodSeconds: 30
            successThreshold: 1
            failureThreshold: 3
          imagePullPolicy: Always
          resources:
            requests:
              memory: \"10Mi\"
              cpu: \"10m\"
          env:
            - name: MY_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name

            - name: \"REPMGR_WAIT_POSTGRES_START_TIMEOUT\"
              value: \"600\"
            - name: \"REPLICATION_PRIMARY_HOST\"
              value: \"$PROJECT-db-node-0.$PROJECT-db\"
            - name: \"PARTNER_NODES\"
              value: \"$nodes\"
            - name: \"NODE_NAME\"
              value: \"\$(MY_POD_NAME)\"
            - name: \"CLUSTER_NODE_NETWORK_NAME\"
              value: \"\$(MY_POD_NAME).$PROJECT-db\"

            - name: \"CONFIGS\"
              value: \"wal_keep_segments:250,shared_buffers:300MB,archive_command:'/bin/true'\"

            # Work DB
            - name: \"POSTGRES_DB\"
              valueFrom:
                configMapKeyRef:
                  name: $PROJECT-config
                  key: app.db.database
            - name: \"POSTGRES_USER\"
              valueFrom:
                secretKeyRef:
                  name: $PROJECT-secret
                  key: app.db.user
            - name: \"POSTGRES_PASSWORD\"
              valueFrom:
                secretKeyRef:
                  name: $PROJECT-secret
                  key: app.db.password

            # Cluster configs
            - name: \"CLUSTER_NAME\"
              valueFrom:
                configMapKeyRef:
                  name: $PROJECT-config
                  key: app.db.cluster.name
            - name: \"REPLICATION_DB\"
              valueFrom:
                configMapKeyRef:
                  name: $PROJECT-config
                  key: app.db.cluster.replication.db
            - name: \"REPLICATION_USER\"
              valueFrom:
                secretKeyRef:
                  name: $PROJECT-secret
                  key: app.db.cluster.replication.user
            - name: "REPLICATION_PASSWORD"
              valueFrom:
                secretKeyRef:
                  name: $PROJECT-secret
                  key: app.db.cluster.replication.password
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: db-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: db-data" >> $PROJECT/nodes.yaml
}

function create_pgpool() {
    echo "apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: $PROJECT
  name: $PROJECT-database-pgpool
  labels:
    name: database-balancer
    node: pgpool
    system: $PROJECT
    app: $PROJECT
spec:
  selector:
    matchLabels:
      system: $PROJECT
  replicas: 2
  revisionHistoryLimit: 5
  template:
    metadata:
      name: database-pgpool
      labels:
        name: database-balancer
        node: pgpool
        system: $PROJECT
        app: $PROJECT
    spec:
      containers:
      - name: database-pgpool
        image: hawickhuang/ha-pgpool:10
        livenessProbe:
          exec:
            command: ['bash', '-c', '/usr/local/bin/pgpool/has_write_node.sh && /usr/local/bin/pgpool/has_enough_backends.sh']
          initialDelaySeconds: 600
          timeoutSeconds: 10
          periodSeconds: 30
          successThreshold: 1
          failureThreshold: 3
        imagePullPolicy: Always
        resources:
          requests:
            memory: \"100Mi\"
            cpu: \"10m\"

        ports:
          - containerPort: 5432
        env:
          # pcp
          - name: \"CONFIGS\"
            value: \"num_init_children:60,max_pool:4,client_idle_limit:900,connection_life_time:300\"
          - name: \"PCP_USER\"
            valueFrom:
              secretKeyRef:
                name: $PROJECT-secret
                key: app.db.pool.pcp.user
          - name: \"PCP_PASSWORD\"
            valueFrom:
              secretKeyRef:
                name: $PROJECT-secret
                key: app.db.pool.pcp.password

          # Cluster configs  to hearbit checks
          - name: \"CHECK_USER\"
            valueFrom:
              secretKeyRef:
                name: $PROJECT-secret
                key: app.db.cluster.replication.user
          - name: \"CHECK_PASSWORD\"
            valueFrom:
              secretKeyRef:
                name: $PROJECT-secret
                key: app.db.cluster.replication.password
          - name: \"DB_USERS\"
            valueFrom:
              secretKeyRef:
                name: $PROJECT-secret
                key: app.db.pool.users
          - name: \"BACKENDS\"
            valueFrom:
              configMapKeyRef:
                name: $PROJECT-config
                key: app.db.pool.backends
---
apiVersion: v1
kind: Service
metadata:
  namespace: $PROJECT
  name: $PROJECT-pgpool
  labels:
    name: database-balancer
    node: pgpool
    system: $PROJECT
spec:
  ports:
    - port: 5432
      targetPort: 5432
  selector:
    name: database-balancer
    node: pgpool
    system: $PROJECT" >> $PROJECT/pgpool.yaml
}

while getopts p:r:u:w:m:s:f:h OPT;do
    case $OPT in
        p)
            PROJECT=$OPTARG
            ;;
        r)
            REPLICAS=$OPTARG
            ;;
        u)
            USER=$OPTARG
            DB_USER=$( echo -n $OPTARG| base64)
            REPLICA_USER=$( echo -n $OPTARG| base64)
            POOL_PCP_USER=$( echo -n $OPTARG| base64)
            ;;
        w)
            PASS=$OPTARG
            DB_PASSWORD=$( echo -n $OPTARG| base64)
            REPLICA_PASSWORD=$( echo -n $OPTARG| base64)
            POOL_PCP_PASSWORD=$( echo -n $OPTARG| base64)
            ;;
        s)
            STORAGE=$OPTARG
            ;;
        f)
            CEPH_PATH=$OPTARG
            ;;
        m)
            MONITORS=$OPTARG
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
    POOL_USERS="$( echo -n $USER:$PASS | base64 )"
done

mkdir ./$PROJECT
create_namespace
create_configs
create_pv
create_pvc
create_services
create_nodes
create_pgpool
kubectl create -f $PROJECT/namespace.yaml
sleep 1
kubectl create -f $PROJECT/configs.yaml
sleep 1
kubectl create -f $PROJECT/pv.yaml
sleep 1
kubectl create -f $PROJECT/pvc.yaml
sleep 1
kubectl create -f $PROJECT/service.yaml
sleep 1
kubectl create -f $PROJECT/nodes.yaml
sleep 1
kubectl create -f $PROJECT/pgpool.yaml
sleep 1
