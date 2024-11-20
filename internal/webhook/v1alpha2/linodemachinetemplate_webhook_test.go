/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha2

import (
	infrav1alpha2 "github.com/linode/cluster-api-provider-linode/api/v1alpha2"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("LinodeMachineTemplate Webhook", func() {
	var (
		obj    *infrav1alpha2.LinodeMachineTemplate
		oldObj *infrav1alpha2.LinodeMachineTemplate
	)

	BeforeEach(func() {
		obj = &infrav1alpha2.LinodeMachineTemplate{}
		oldObj = &infrav1alpha2.LinodeMachineTemplate{}
		Expect(oldObj).NotTo(BeNil(), "Expected oldObj to be initialized")
		Expect(obj).NotTo(BeNil(), "Expected obj to be initialized")
		// TODO (user): Add any setup logic common to all tests
	})

	AfterEach(func() {
		// TODO (user): Add any teardown logic common to all tests
	})

	Context("When creating LinodeMachineTemplate under Conversion Webhook", func() {
		// TODO (user): Add logic to convert the object to the desired version and verify the conversion
		// Example:
		// It("Should convert the object correctly", func() {
		//     convertedObj := &infrav1alpha2.LinodeMachineTemplate{}
		//     Expect(obj.ConvertTo(convertedObj)).To(Succeed())
		//     Expect(convertedObj).ToNot(BeNil())
		// })
	})

})