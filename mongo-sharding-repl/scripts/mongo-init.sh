#!/bin/bash

docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
exit();
EOF

docker compose exec -T shard1-master mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-master:27018" },
    { _id: 1, host: "shard1-slave1:27019" },
    { _id: 2, host: "shard1-slave2:27020" }
  ]
})
exit();
EOF

docker compose exec -T shard2-master mongosh --port 27021 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-master:27021" },
    { _id: 1, host: "shard2-slave1:27022" },
    { _id: 2, host: "shard2-slave2:27023" }
  ]
})
exit();
EOF

sleep 5 # хак, без него все время 

docker compose exec -T mongos_router mongosh --port 27024 --quiet <<EOF
sh.addShard("shard1/shard1-master:27018")
sh.addShard("shard2/shard2-master:27021")
exit();
EOF

docker compose exec -T mongos_router mongosh --port 27024 --quiet <<EOF
sh.enableSharding("somedb")
EOF


docker compose exec -T mongos_router mongosh --port 27024 --quiet <<EOF
use somedb
db.createCollection("helloDoc")
db.helloDoc.createIndex({ _id: "hashed" })
sh.shardCollection("somedb.helloDoc", { _id: "hashed" })
exit();
EOF

docker compose exec -T mongos_router mongosh --port 27024 --quiet <<EOF
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i});
exit();
EOF

# print docs count
docker compose exec -T shard1-master mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2-master mongosh --port 27021 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF