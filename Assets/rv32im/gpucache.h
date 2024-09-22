			static uint4 cachesetsdata[CACHE_BLOCKS] = (uint4[CACHE_BLOCKS])0;
			static uint  cachesetsaddy[CACHE_BLOCKS] = (uint[CACHE_BLOCKS])0;
			static uint  cache_usage = 0;
			
			uint U4Select( uint4 v, uint w )
			{
				switch( w )
				{
				case 1: return v.y;
				case 2: return v.z;
				case 3: return v.w;
				default: return v.x;
				}
			}

			void SetField( inout uint4 vv, uint val, uint w )
			{
				switch( w )
				{
					case 0: vv.x = val; break;
					case 1: vv.y = val; break;
					case 2: vv.z = val; break;
					case 3: vv.w = val; break;
				}
			}
			
			uint4 LoadMemInternalBlockNoCache( uint ptr )
			{
				uint4 ret;
				ptr -= MINIRV32_RAM_IMAGE_OFFSET;
				if( ptr < MEMORY_SPLIT )
				{
					uint blockno = ptr >> 4;
					ret = FlashSystemAccess( blockno );	
				}
				else if( ptr < 0x70000000 )
				{
					ptr -= MEMORY_SPLIT;
					uint blockno = ptr >> 4;
					ret = MainSystemAccess( blockno );
				}
				else
				{
					ptr -= 0x70000000;
					uint px = ptr >> 4;
					ret = _BackScreenFromCamera[uint2(px%16, 8-px/16)];
				}
				return ret;
			}

			// Only use if aligned-to-4-bytes.
			uint LoadMemInternalRB( uint ptr )
			{
				ptr -= MINIRV32_RAM_IMAGE_OFFSET;
				uint remainder4 = ((ptr&0xc)>>2);
				uint4 ret = 0;
				
				if( ptr < MEMORY_SPLIT )
				{
					uint blockno = ptr >> 4;
					ret = FlashSystemAccess( blockno );	
				}
				else
				{
					ptr -= MEMORY_SPLIT;
					uint blockno = ptr >> 4;
					uint blocknop1 = blockno+1;
					uint hash = (blockno % (CACHE_BLOCKS/CACHE_N_WAY)) * CACHE_N_WAY;
					uint4 block;
					uint ct = 0;
					uint i;
					for( i = 0; i < CACHE_N_WAY; i++ )
					{
						ct = cachesetsaddy[i+hash];
						if( ct == blocknop1 )
						{
							// Found block.
							ret = cachesetsdata[(i+hash)];
							break;
						}
						else if( ct == 0 )
						{
							// else, no block found. Read data.
							ret = MainSystemAccess( blockno );
							break;
						}
					}
				}
				return U4Select( ret, remainder4 );
			}

			// Store mem internal word (Only use if guaranteed word-alignment)
			void StoreMemInternalRB( uint ptr, uint val )
			{
				ptr -= MINIRV32_RAM_IMAGE_OFFSET;
				ptr -= MEMORY_SPLIT;
				uint ptrleftover = (ptr & 0xc)>>2;
				//printf( "STORE %08x %08x\n", ptr, val );
				uint blockno = ptr >> 4;  
				uint blocknop1 = blockno+1;
				// ptr will be aligned.
				// perform a 4-byte store.
				uint hash = (blockno % (CACHE_BLOCKS/CACHE_N_WAY)) * CACHE_N_WAY;
				uint hashend = hash + CACHE_N_WAY;
				uint4 block;
				uint ct = 0;

				for( ; hash < hashend; hash++ )
				{
					ct = cachesetsaddy[hash];
					if( ct == 0 )
					{
						ct = cachesetsaddy[hash] = blocknop1;
						cache_usage++;
						uint4assign( cachesetsdata[hash], MainSystemAccess( blockno ) );

						if( hash == hashend-1 )
						{
							cache_usage = MAX_FCNT;
						}
					}
					if( ct == blocknop1 )
					{
						// Found block.
						SetField( cachesetsdata[ hash ], val, ptrleftover );
						return;
					}
				}
#if 0				
				// NOTE: It should be impossible for i to ever be or exceed 1024.
				// We catch it early here.
				if( hash == hashend )
				{
					// We have filled a cache line.  We must cleanup without any other stores.
					cache_usage = MAX_FCNT;
					//printf( "OVR Please Flush at %08x\n", ptr );
					//fprintf( stderr, "ERROR: SERIOUS OVERFLOW %d\n", -1 );
					//exit( -99 );
					
					// This is tricky: We are actually overloading.
					//uint4assign( block, MainSystemAccess( blockno ) );
					//block[(ptr&0xf)>>2] = val;
					//EmitGeo( blockno, block );
					//XXX WARN XXX TODO  Can we emit here?
					return;
				}
				cachesetsaddy[hash] = blocknop1;
				uint4assign( cachesetsdata[hash], MainSystemAccess( blockno ) );
				SetField( cachesetsdata[ hash ], val, ptrleftover );

				// Make sure there's enough room to flush processor state
				if( hash == hashend-1 )
				{
					cache_usage = MAX_FCNT;
				}
#endif
			}

			// NOTE: len does NOT control upper bits.
			uint LoadMemInternal( uint ptr, uint len )
			{
				uint lenx8mask = ((uint)(-1)) >> (((4-len) & 3) * 8);
				uint remo = ptr & 3;
				if( remo > 0 )
				{
					if( len > 4 - remo )
					{
						// Must be split into two reads.
						uint ret0 = LoadMemInternalRB( ptr & (~3) );
						uint ret1 = LoadMemInternalRB( (ptr & (~3)) + 4 );
						uint ret = lenx8mask & ((ret0 >> (remo*8)) | (ret1<<((4-remo)*8)));
						return ret;
					}
					else
					{
						// Can just be one.
						uint ret = LoadMemInternalRB( ptr & (~3) );
						ret = (ret >> (remo*8)) & lenx8mask;
						return ret;
					}
				}
				else
					return LoadMemInternalRB( ptr ) & lenx8mask;
			}
			
			void StoreMemInternal( uint ptr, uint val, uint len )
			{
#if CHECKRAM
				memcpy( ram_image_shadow + ptr, &val, len );
#endif
				uint remo = (ptr & 3);
				uint remo8 = remo * 8;
				uint ptrtrunc = ptr - remo;
				uint lenx8mask = ((uint)(-1)) >> (((4-len) & 3) * 8);
				if( remo + len > 4 )
				{
					// Must be split into two writes.
					// remo = 2 for instance, 
					uint val0 = LoadMemInternalRB( ptrtrunc );
					uint val1 = LoadMemInternalRB( ptrtrunc + 4 );
					uint mask0 = lenx8mask << (remo8);
					uint mask1 = lenx8mask >> (32-remo8);
					val &= lenx8mask;
					val0 = (val0 & (~mask0)) | ( val << remo8 );
					val1 = (val1 & (~mask1)) | ( val >> (32-remo8) );
					StoreMemInternalRB( ptrtrunc, val0 );
					StoreMemInternalRB( ptrtrunc + 4, val1 );
					//printf( "RESTORING: %d %d @ %d %d / %08x %08x -> %08x, %08x %08x -> %08x\n", remo, len, ptrtrunc, ptrtrunc+4, mask0, val, val0, mask1, val, val1 );
				}
				else if( len != 4 )
				{
					// Can just be one call.
					// i.e. the smaller-than-word-size write fits inside the word.
					uint valr = LoadMemInternalRB( ptrtrunc );
					uint mask = lenx8mask << remo8;
					valr = ( valr & (~mask) ) | ( ( val & lenx8mask ) << (remo8) );
					StoreMemInternalRB( ptrtrunc, valr );
					//printf( "RESTORING: %d %d @ %d / %08x %08x -> %08x\n", remo, len, ptrtrunc, mask, val, valr );
				}
				else
				{
					// Else it's properly aligned.
					StoreMemInternalRB( ptrtrunc, val );
				}
			}

			#define MINIRV32_CUSTOM_MEMORY_BUS
			uint MINIRV32_LOAD4( uint ofs ) { return LoadMemInternal( ofs, 4 ); }
			#define MINIRV32_STORE4( ofs, val ) { StoreMemInternal( ofs, val, 4 ); if( cache_usage >= MAX_FCNT ) icount = MAXICOUNT;}
			uint MINIRV32_LOAD2( uint ofs ) { uint tword = LoadMemInternal( ofs, 2 ); return tword; }
			uint MINIRV32_LOAD1( uint ofs ) { uint tword = LoadMemInternal( ofs, 1 ); return tword; }
			int MINIRV32_LOAD2_SIGNED( uint ofs ) { uint tword = LoadMemInternal( ofs, 2 ); if( tword & 0x8000 ) tword |= 0xffff0000;  return tword; }
			int MINIRV32_LOAD1_SIGNED( uint ofs ) { uint tword = LoadMemInternal( ofs, 1 ); if( tword & 0x80 )   tword |= 0xffffff00; return tword; }
			#define MINIRV32_STORE2( ofs, val ) { StoreMemInternal( ofs, val, 2 ); if( cache_usage >= MAX_FCNT ) icount = MAXICOUNT; }
			#define MINIRV32_STORE1( ofs, val ) { StoreMemInternal( ofs, val, 1 ); if( cache_usage >= MAX_FCNT ) icount = MAXICOUNT; }

			// From pi_maker's VRC RVC Linux
			// https://github.com/PiMaker/rvc/blob/eb6e3447b2b54a07a0f90bb7c33612aeaf90e423/_Nix/rvc/src/emu.h#L255-L276
			#define CUSTOM_MULH \
				case 1: \
				{ \
				    /* FIXME: mulh-family instructions have to use double precision floating points internally atm... */ \
					/* umul/imul (https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/umul--sm4---asm-)       */ \
					/* do exist, but appear to be unusable?                                                           */ \
					precise double op1 = int(rs1); \
					precise double op2 = int(rs2); \
					rval = (uint)((op1 * op2) / 4294967296.0l); /* '/ 4294967296' == '>> 32' */ \
					break; \
				} \
				case 2: \
				{ \
					/* is the signed/unsigned stuff even correct? who knows... */ \
					precise double op1 = int(rs1); \
					precise double op2 = uint(rs2); \
					rval = (uint)((op1 * op2) / 4294967296.0l); /* '/ 4294967296' == '>> 32' */ \
					break; \
				} \
				case 3: \
				{ \
					precise double op1 = uint(rs1); \
					precise double op2 = uint(rs2); \
					rval = (uint)((op1 * op2) / 4294967296.0l); /* '/ 4294967296' == '>> 32' */ \
					break; \
				}
