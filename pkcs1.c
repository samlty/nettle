/* pkcs1.c
 *
 * PKCS1 embedding.
 */

/* nettle, low-level cryptographics library
 *
 * Copyright (C) 2003 Niels Möller
 *  
 * The nettle library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 * 
 * The nettle library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with the nettle library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
 * MA 02111-1307, USA.
 */

#if HAVE_CONFIG_H
# include "config.h"
#endif

#include <assert.h>
#include <string.h>

#include "pkcs1.h"

/* Formats the PKCS#1 padding, of the form
 *
 *   0x00 0x01 0xff ... 0xff 0x00 id ...digest...
 *
 * where the 0xff ... 0xff part consists of at least 8 octets. The 
 * total size equals the octet size of n.
 */
uint8_t *
_pkcs1_signature_prefix(unsigned key_size,
			uint8_t *buffer,
			unsigned id_size,
			const uint8_t *id,
			unsigned digest_size)
{
  unsigned j;
  
  if (key_size < 11 + id_size + digest_size)
    return NULL;

  j = key_size - digest_size - id_size;

  memcpy (buffer + j, id, id_size);
  buffer[0] = 0;
  buffer[1] = 1;
  buffer[j-1] = 0;

  assert(j >= 11);
  memset(buffer + 2, 0xff, j - 3);

  return buffer + j + id_size;
}
