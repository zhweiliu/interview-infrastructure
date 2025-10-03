# interview-infrastructure

本專案示範如何使用 **ArgoCD** 管理 Kubernetes 上的基礎建設與應用程式（包含 ArgoCD 本身）。  
本地端測試環境使用 [k3d](https://k3d.io/) 建立輕量化的 K3s cluster。 

## 專案目標

- 採用 **GitOps** 模式集中管理 Kubernetes 資源  
- 使用 **ArgoCD** 監控 Git Repo，以自動同步資源  
- 透過 repo 內的 **Helm Chart 與 values.yaml** 定義應用，避免手動安裝

### 專案結構

```
argocd/
├── bootstrap/ # 用於安裝與初始化 ArgoCD 本身
└── clusters/
├── apps/
│ └── <app-folders> # 各應用程式的設定 (Helm 或 YAML)
├── applicationset.yaml # ApplicationSet 定義，會自動同步 apps/ 下的應用
├── component # 將應用程式元件化，以利部署時使用
└── pic : 執行結果的截圖
```

### 部署流程
1. 使用 k3d 建立一個本地 Kubernetes cluster。  
2. 套用 `argocd/bootstrap/`，在 cluster 上部署並啟動 ArgoCD。  
3. ArgoCD 啟動後，需要手動套用 `argocd/clusters/apps/applicationset.yaml`。  
4. ApplicationSet 會自動建立並同步 `argocd/clusters/apps/` 目錄下的應用程式：  
   - 若為 Helm 應用，ArgoCD 會使用內建的 Helm 功能渲染 `Chart` 與 `values.yaml`。  
   - 若為純 YAML，則直接套用 manifest。  
5. 進入 ArgoCD UI，即可檢查應用是否正確同步與部署。
6. Postgresql 執行初始化 sql 語法
7. (Optional) 設置 Grafana Dashboard

---

## 前置需求

- [Docker](https://docs.docker.com/get-docker/)  
- [k3d](https://k3d.io/)  
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kubectx+kubens](https://github.com/ahmetb/kubectx)

---

## 建立 Cluster

建立一個名為 `infrastructure` 的 k3d cluster：  

```bash
k3d cluster create infrastructure
```

確認 cluster 狀態：

```bash
kubectl cluster-info
kubectl get nodes
```

### 建立所有需要的 k3d node

k3d node 如同 k8s 的 node，是提供掛載 Pod 的機器，而 k3d node 本身也是輕量化的虛擬機。  
以下示範如何在名為 `infrastructure` 的 cluster 中建立所有需要的 agent nodes：

```bash
k3d node create clickhouse-operator --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=clickhouse-operator"
k3d node create clickhouse-server --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=clickhouse" --k3s-node-label "topology.gke.io/zone=asia-east1-a"
k3d node create prometheus --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=prometheus"
k3d node create metabase --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=metabase"
k3d node create postgresql --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=postgresql"
k3d node create grafana --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=grafana"
k3d node create prefect --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=prefect"
k3d node create prometheus-prefect-exporter --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=prometheus-prefect-exporter"
k3d node create prefect-work-pool --role agent --cluster infrastructure --k3s-node-label "cloud.google.com/gke-nodepool=prefect-work-pool"
```

> ✅ 驗證點：使用 kubectl get nodes 可以看到所有建立的 node，狀態應為 Ready。

---

## 部署 ArgoCD

ArgoCD 相關資源定義於本 repo：

- `argocd/bootstrap/`：ArgoCD 安裝與基礎設定  
- `argocd/clusters/apps/applicationset.yaml`：定義 ApplicationSet，會自動同步 `argocd/clusters/apps/` 目錄下的應用

### 安裝 ArgoCD：

```bash
kubectl apply -k argocd/bootstrap/
```

---

## 存取 ArgoCD UI

取得初始密碼：

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

透過 port-forward 存取 UI：

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

開啟瀏覽器，進入 [https://localhost:8080](https://localhost:8080)，  
使用帳號 `admin` 與上一步取得的密碼登入。

---

## 部署 Applications

`argocd/clusters/apps/applicationset.yaml`：定義 ApplicationSet，會自動同步 `argocd/clusters/apps/` 目錄下的應用

因此在 namespace `argocd` 部署 `applicationset.ymal` 檔案即可

```bash
kubectl apply -k argocd/clusters/apps/applicationset.yaml
```

---

## PostgreSQL 資料庫初始化 (`init.sql`)

在初始化 PostgreSQL 資料庫之前，需要先建立本地到 cluster 的連線

### 建立 port-forward

```bash
kubectl get svc -n database
# NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
# chi-chi-standard-shard-0-0   ClusterIP   None            <none>        9000/TCP,8123/TCP,9009/TCP   3d18h
# metabase                     ClusterIP   10.43.134.142   <none>        8300/TCP                     3d17h
# postgresql                   ClusterIP   10.43.125.74    <none>        5432/TCP                     3d18h
# service-chi                  ClusterIP   10.43.197.99    <none>        8123/TCP,9000/TCP            3d18h
# service-standard             ClusterIP   10.43.47.116    <none>        8123/TCP,9000/TCP            3d18h

# port-forward
kubectl port-forward service/postgresql 5432:5432 -n database
```

### 透過 DB 工具執行 sql 語法

使用任意 DB Tool 連線到 postgresql( 推薦 **[DBeaver](https://dbeaver.io/)** )

```bash
# 此處 postgresql 預設的 superuser 帳號密碼如下
帳號: admin
密碼: admin
```

登入後在 postgresql 上執行初始化 sql 
```bash
# 初始化 sql 檔案位置
argocd/clusters/apps/database/postgresql/init.sql
```

---

## (Optional) Grafana 設置 

在這個 repository 中，ArgoCD 會同時安裝 Prometheus 與 Grafana。  
以下說明如何在 Grafana 中設置 Prometheus 作為資料來源，並顯示關注的 metrics。

與此 repository 搭配的 ELT pipeline [interview-pipeline](https://github.com/zhweiliu/interview-pipeline) 會定期將關注指標輸出到 Prometheus。

### 設置 Prometheus 作為 Data Source

將 Grafana service port-forward 到 local

```bash
kubectl port-forward service/grafana 3000:3000 -n monitoring
```

開啟瀏覽器，訪問：
```bash
localhost:3000
```

左側選單點擊 **Data sources** → 右上角 **+ Add new data source** → 選擇 **Prometheus**。

在 **Connection** 欄位輸入 Prometheus server URL：

```bash
http://app-prometheus-server.prometheus.svc.cluster.local:80
```

點擊最下方 **Save & test** 儲存。

### 增加 Dashboard 與 Panels

[interview-pipeline](https://github.com/zhweiliu/interview-pipeline) 每天執行完成後，會輸出以下 metrics 到 Prometheus：

**Anomaly Detection**
* **anomaly_unit_price_count** : 單價異常資料筆數  
* **anomaly_quantity_count** : 數量異常資料筆數  
* **missing_customer_id_ratio** : 資料集缺失 Customer ID 的比例  

**Sales Summary**
* **latest_min_total_amount** : 當日交易最小總金額  
* **latest_max_total_amount** : 當日交易最大總金額  
* **latest_median_total_amount** : 當日交易總金額中位數  
* **latest_avg_total_amount** : 當日交易總金額平均數  
* **latest_sales_volume** : 當日所有交易加總金額  

設置完成後，Dashboard 顯示效果如下：

![grafana-dashboard](pic/grafana-dashboard.png)
