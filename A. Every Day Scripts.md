
## **Azure Cloud Management (The Hardware)**

### **The "Wake Up" Call**

*Boots the VM and starts the API server.*

```powershell
az aks start --name lab-learning-aks --resource-group rg-learning-aks
```

### **The "Shutdown Protocol" (Money Saver)**

*Pauses the VM billing. Does NOT delete data.*

```powershell
az aks stop --name lab-learning-aks --resource-group rg-learning-aks
```

### **Connect to Cluster**

*Downloads the `kubeconfig` keys to your laptop so `kubectl` can talk to Azure.*

```powershell
az aks get-credentials --resource-group rg-terraform-lab --name aks-terraform-lab --overwrite-existing
```

### **List Azure Container Registries**

```
az acr list --resource-group rg-terraform-lab --query "[].name" --output tsv
```



-----

## **Kubernetes Essentials (The Inner Loop)**

### **Check Status**

```powershell
# Check physical hardware (VMs)
kubectl get nodes

# Check everything in the current namespace
kubectl get all

# Watch for changes live (Ctrl+C to stop)
kubectl get pods -w
kubectl get service -w
```

### **Deploy & Update**

```powershell
# Apply a specific file
kubectl apply -f nginx-deployment.yaml

# Apply EVERY file in the current folder
kubectl apply -f .
```

### **The Developer Tunnel**

*Access an internal (ClusterIP) service from your local laptop.*

```powershell
# Syntax: kubectl port-forward service/<service-name> <local-port>:<remote-port>
kubectl port-forward service/nginx-service 8080:80
```

*(Then open http://localhost:8080)*

-----

## **Debugging & Troubleshooting**

### **"Why is my Pod Pending/Crashed?"**

*The \#1 debugging command. Shows events, errors, and capacity issues.*

```powershell
kubectl describe pod <pod-name>
```

### **The "Restart" Button**

*Forces a deployment to re-pull images or pick up config changes.*

```powershell
# Note: Use the RESOURCE name, not the file name!
kubectl rollout restart deployment/nginx-deployment
```

### **Clean Up Contexts**

*Remove old/broken cluster connections from your config.*

```powershell
# List all contexts
kubectl config get-contexts

# Delete a specific one
kubectl config delete-context learning-aks-lab
```

-----

## **Helm (Package Manager)**

### **Repo Management**

```powershell
# Add a store shelf (e.g., Nginx)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Update the catalog
helm repo update
```

### **Chart Creation & Management**

```powershell
# Create a new chart skeleton
helm create my-nginx-app

# Install a local chart (Release Name: my-release)
helm install my-release ./my-nginx-app

# Apply changes (Update) to a release
helm upgrade my-release ./my-nginx-app
```

### **Uninstall**

*Removes the app and releases resources (like Public IPs).*

```powershell
helm uninstall my-release
```

-----

## **Windows Network Fixes (The Gremlins)**

### **The "Nuclear" Network Reset**

*Run as Administrator if you lose internet or cannot connect to Azure.*

```powershell
netsh int ip reset
netsh winsock reset
# RESTART COMPUTER AFTER RUNNING THIS
```

There you go\! Save this in your notes. See you on the weekend for **Infrastructure as Code**\! 🏗️