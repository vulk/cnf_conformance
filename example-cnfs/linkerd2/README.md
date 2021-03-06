# What is [Linkerd](https://linkerd.io/)?

Linkerd is a service mesh, designed to give platform-wide observability, reliability, and security without requiring configuration or code changes.

## Pre-req:

Follow [Pre-req steps](../../INSTALL.md#pre-requisites), including
Set the KUBECONFIG environment to point to the remote K8s cluster

### Automated Envoy installation

Run cnf-testsuite setup

```
crystal src/cnf-testsuite.cr setup
```

Install linkerd

```
crystal src/cnf-testsuite.cr cnf_setup cnf-path=example-cnfs/linkerd
```

Run the test suite:

```
crystal src/cnf-testsuite.cr all
```

linkerd cleanup

```
crystal src/cnf-testsuite.cr cnf_cleanup cnf-path=example-cnfs/linkerd
```
