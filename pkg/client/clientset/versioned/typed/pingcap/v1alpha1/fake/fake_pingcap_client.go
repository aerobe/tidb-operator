// Copyright 2019. PingCAP, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// See the License for the specific language governing permissions and
// limitations under the License.

// Code generated by client-gen. DO NOT EDIT.

package fake

import (
	v1alpha1 "github.com/pingcap/tidb-operator/pkg/client/clientset/versioned/typed/pingcap/v1alpha1"
	rest "k8s.io/client-go/rest"
	testing "k8s.io/client-go/testing"
)

type FakePingcapV1alpha1 struct {
	*testing.Fake
}

func (c *FakePingcapV1alpha1) Backups(namespace string) v1alpha1.BackupInterface {
	return &FakeBackups{c, namespace}
}

func (c *FakePingcapV1alpha1) BackupSchedules(namespace string) v1alpha1.BackupScheduleInterface {
	return &FakeBackupSchedules{c, namespace}
}

func (c *FakePingcapV1alpha1) DataResources(namespace string) v1alpha1.DataResourceInterface {
	return &FakeDataResources{c, namespace}
}

func (c *FakePingcapV1alpha1) Restores(namespace string) v1alpha1.RestoreInterface {
	return &FakeRestores{c, namespace}
}

func (c *FakePingcapV1alpha1) TidbClusters(namespace string) v1alpha1.TidbClusterInterface {
	return &FakeTidbClusters{c, namespace}
}

// RESTClient returns a RESTClient that is used to communicate
// with API server by this client implementation.
func (c *FakePingcapV1alpha1) RESTClient() rest.Interface {
	var ret *rest.RESTClient
	return ret
}
