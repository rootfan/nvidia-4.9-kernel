/*
 * Copyright (C) 2014-2016, NVIDIA CORPORATION. All rights reserved.
 *
 * Linux spesific hv syscall tests
 *
 * This header is BSD licensed so anyone can use the definitions to implement
 * compatible drivers/servers.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of NVIDIA CORPORATION nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL NVIDIA CORPORATION OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <linux/init.h>
#include <linux/string.h>
#include <linux/printk.h>

#include <soc/tegra/virt/syscalls.h>

/* #define TEGRA_HVC_DEBUG	*/

#if defined(TEGRA_HVC_DEBUG)
struct hyp_ipa_pa_info info;

/*
 * Test this hypercall by inspecting its result in console output.
 * Usually the given ipa value is a valid mapping in the guest.
 */
int test_hyp_read_ipa_pa_info(void)
{
	uint64_t ipa = 0x80000000;
	int guestid = 0;
	int err;

	memset(&info, 0, sizeof(info));

	err = hyp_read_ipa_pa_info(&info, 0, ipa);
	if (err < 0)
		printk(KERN_DEBUG " %s: syscall failed for IPA=%llx, "
		       "guestid=%d, err=%d\n", __func__, ipa, guestid, err);
	else
		printk(KERN_DEBUG " %s: for IPA=%llx, guestid=%d, we got, "
		       "PA base: %llx, offset: %llx, size: %llx\n",
		       __func__, ipa, guestid, info.base, info.offset,
		       info.size);
	return 0;
}
late_initcall(test_hyp_read_ipa_pa_info);
#endif

