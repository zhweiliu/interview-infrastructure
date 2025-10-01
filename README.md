# interview-infrastructure

## 專案概述 (Project Overview)

本專案旨在提供一套基於 **k3d** 和 **ArgoCD** 的輕量級基礎設施部署範例。透過 **GitOps** 的方式，您可以在本地快速建立一個模擬的 Kubernetes 環境，並自動部署應用程式所需的相關服務（如資料庫、Redis、應用程式等）。

---

## 前提設置與環境準備 (Prerequisites & Setup)

在開始部署之前，請確保您的本地環境已安裝以下必要工具，並依序完成以下步驟。

### 1. 安裝 Docker Desktop

k3d 依賴 Docker 來建立和管理輕量級的 Kubernetes 叢集節點。

* **安裝：** 請前往 [Docker 官方網站](https://www.docker.com/products/docker-desktop/) 下載並安裝 **Docker Desktop**，並確保其正在運行。

### 2. 安裝 k3d 並建立 K3d 叢集與 k3d Node

k3d 是在 Docker 中運行 K3s 的工具，用於在本地快速搭建輕量級的 Kubernetes 叢集。

* **安裝 k3d** (請參考官方文件選擇適合您作業系統的安裝方式)。
* **建立 k3d 叢集：** 執行以下指令建立一個名為 `interview-cluster` 的叢集。

    ```bash
    k3d cluster create interview-cluster
    ```
* **建立所有需要的 k3d node :** k3d node 如同 k8s 的 node，是提供掛載 pod 的機器，而 k3d node 本身也是輕量化的虛擬機

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

### 3. 安裝 kubectl, kubectx, kubens

請確保已安裝這些常用的 Kubernetes 命令列工具：

* **kubectl** (Kubernetes 官方命令列工具)
* **kubectx** (叢集上下文切換工具)
* **kubens** (命名空間切換工具)

### 4. 在 K3d 叢集預先安裝 ArgoCD

我們將使用 ArgoCD 來管理叢集內的應用程式部署。請依照[官方步驟](https://argo-cd.readthedocs.io/en/stable/getting_started/)執行，以下列出重要步驟：

1.  **建立 ArgoCD 專屬的 Namespace：**

    ```bash
    kubectl create namespace argocd
    ```

2.  **套用官方 ArgoCD 安裝 Manifest：**

    ```bash
    kubectl apply -n argocd -f [https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml](https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml)
    ```

    **或是套用 Repo 內提供的 bootstarp:**

    ```bash
    kubectl apply -k argocd/bootstarp/ -n argocd
    ```

3.  **檢查部署狀態：**
    等待所有 ArgoCD 相關 Pod 啟動完成。

    ```bash
    kubectl get pods -n argocd
    ```

### 5. 套用 ApplicationSet 定義檔案

此步驟將告知 ArgoCD 應從 Git 倉庫中同步哪些應用程式定義。

* **指令：** 在 `argocd` namespace 下套用 **`argocd/cluster/applicationset.yaml`** 檔案：

    ```bash
    kubectl apply -n argocd -f argocd/cluster/applicationset.yaml
    ```

### 6. 透過 Port-Forward 存取 ArgoCD Web UI

使用 Port-Forward 將 ArgoCD Server 的 443 埠轉發到本地的 8443 埠，以便在瀏覽器上查看部署狀態。

* **指令：** 執行以下指令進行 Port-Forward：

    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8443:443
    ```

* **瀏覽器存取 URL：** Port-Forward 成功後，您可以在瀏覽器上透過以下網址存取 ArgoCD Web UI：

    ```
    https://localhost:8443
    ```

    > **注意：** 首次連線可能會遇到 SSL 憑證警告，請選擇繼續存取。

### 7. PostgreSQL 資料庫初始化 (`init.sql`)

當 PostgreSQL 服務透過 ArgoCD 部署完成並運行後，您需要執行 `init.sql` 來初始化資料庫結構或數據。

**執行步驟和方法：**

1.  **確認 Service 名稱：** 查找 PostgreSQL 的 Service Port。

    ```bash
    kubectl get svc -n database
    # NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
    # chi-chi-standard-shard-0-0   ClusterIP   None            <none>        9000/TCP,8123/TCP,9009/TCP   3d18h
    # metabase                     ClusterIP   10.43.134.142   <none>        8300/TCP                     3d17h
    # postgresql                   ClusterIP   10.43.125.74    <none>        5432/TCP                     3d18h
    # service-chi                  ClusterIP   10.43.197.99    <none>        8123/TCP,9000/TCP            3d18h
    # service-standard             ClusterIP   10.43.47.116    <none>        8123/TCP,9000/TCP            3d18h
    ```

2.  **Port-forward postgresql service：** 

    ```bash
    kubectl port-forward service/postgresql 5432:5432 -n database
    ```

3.  **使用任意 DB Tool 連線到 postgresql：** 推薦 [DBeaver](https://dbeaver.io/)。

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

## 使用指南 (Usage Guide)

1.  **登入 ArgoCD：**
    * **使用者名稱：** `admin`
    * **密碼：** 初始密碼是 ArgoCD API Server Pod 的名稱。您可以使用以下指令獲取：

        ```bash
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
        ```

2.  **同步應用程式：**
    登入 ArgoCD 後，`ApplicationSet` 應該會自動開始同步您定義在倉庫中的所有應用程式。您可以透過 Web UI 觀察所有服務 (如：`postgres`, `redis`, `backend`, `frontend` 等) 是否已成功部署並達到 **`Healthy`** 和 **`Synced`** 狀態。

3.  **存取部署的服務：**
    根據您的應用程式定義，使用 `kubectl port-forward` 或 Ingress (如果已配置) 來存取部署在 K3d 叢集中的服務。

---

## Grafana 設置 

在這個 repository 內， Argocd 會同時安裝 Prometheus 和 Grafana ，以下說明 Grafana 設置獲取 Prometheus metrics 的步驟

與這個 repository 搭配的 ELT pipeline [inverview-pipeline](https://github.com/zhweiliu/interview-pipeline) 會定期將關注的指標輸出到 prometheus

### 1. 設置 Prometheus 作為 Data Source

將 Grafana service port-forward 到 local

```bash
kubectl port-forward service/grafana 3000:3000 -n monitoring
```

開啟網頁，透過 URL 進入 Grafana
```bash
localhost:3000
```

左側選單點擊 Data sources -> 右上角 「+ Add new data source」 -> 選擇 Prometheus

在 Connection 輸入 prometheus server 的 URL
```bash
http://app-prometheus-server.prometheus.svc.cluster.local:80
```

點擊最下方 「Save & test」 儲存

### 2. 增加 Dashboard 與 Panels

[inverview-pipeline](https://github.com/zhweiliu/interview-pipeline) 每天執行完成後，會輸出以下的 metrics 到 prometheus

**Anomaly Detection**
* **anomaly_unit_price_count :** 單價異常資料筆數
* **anomaly_quantity_count :** 數量異常資料筆數
* **missing_customer_id_ratio :** 資料集缺失 Customer ID 的比例

**Sales Summary**
* **latest_min_total_amount :** 當日交易最小總金額
* **latest_max_total_amount :** 當日交易最大總金額
* **latest_median_total_amount :** 當日交易總金額中位數
* **latest_avg_total_amount :** 當日交易總金額平均數
* **latest_sales_volume :** 當日所有交易加總金額

設置完成後，如下圖所示

![grafana-dashboard](pic/grafana-dashboard.png)
