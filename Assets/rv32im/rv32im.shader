Shader "rv32ima/compute"
{
	Properties
	{
		_MainSystemMemory( "Main System Memory", 2D ) = "black" { }
		[ToggleUI] _SingleStep( "Single Step Enable", float ) = 0.0
		[ToggleUI] _SingleStepGo( "Single Step Go", float ) = 0.0
		_ElapsedTime( "Elapsed Time", float ) = .0001
		_SystemMemorySize( "System Memory Size", Vector ) = ( 0, 0, 0, 0)
	}
	SubShader
	{
		Tags { }

		Pass
		{
			ZTest Always 
			Blend One Zero

			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 5.0

			struct appdata
			{
                float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex	: SV_POSITION;
				uint batchID	: TEXCOORD2;
			};
			
			v2f vert(appdata IN)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(IN.vertex);
				return o;
			}
			
			
			float4 frag (v2f i) : SV_Target
            {
				return 0;
			}
			
			ENDCG
		}
		
		Pass
		{
			ZTest Always 
			//Blend One Zero

			CGPROGRAM
			
			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag
			#pragma exclude_renderers d3d11_9x
			#pragma exclude_renderers d3d9	 // Just tried adding these because of a bgolus post to test,has no impact.
			#pragma target 5.0

			//#pragma skip_optimizations d3d11
			#pragma enable_d3d11_debug_symbols

			uint _SingleStepGo;
			uint _SingleStep;
			float _ElapsedTime;
			#include "vrc-rv32im.cginc"			
			#include "gpucache.h"


			struct appdata
			{
				uint	vertexID	: SV_VertexID;
			};

			struct v2g
			{
				//float4 vertex	: SV_POSITION;
				uint batchID	: TEXCOORD2;
			};
			
			struct g2f
			{
				//XXX: TODO: Can we shrink this down and use Z to somehow indicate location, to reduce number of outputs required from geo?
				float4 vertex : SV_POSITION;
				uint4 color   : TEXCOORD0;				
			};

			v2g vert(appdata IN)
			{
				v2g OUT;
				OUT.batchID = IN.vertexID;
				return OUT;
			}
			
			[maxvertexcount(128)]
			[instance(1)]
			void geo( point v2g input[1], inout PointStream<g2f> stream,
				uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
			{
			#if UNITY_SINGLE_PASS_STEREO
				return;
			#else
			
				int batchID = input[0].batchID; // Should always be 0?

				g2f o;
				uint i;
				uint pixelOutputID = 0;
				uint elapsedUs = _ElapsedTime * 1000000;

				uint state[52] = (uint[52])0;

				// Load state in from main ram.
				uint4 v;
				{
					for( i = 0; i < 13; i++ )
					{
						uint4 v = _MainSystemMemory.Load( uint3( i, SYSTEX_SIZE_Y-1, 0 ) );
						state[i*4+0] = v.x;
						state[i*4+1] = v.y;
						state[i*4+2] = v.z;
						state[i*4+3] = v.w;
					}
				}
				
				state[charout] = 0;

				bool nogo = false;
				
				if( _SingleStep )
				{
					count = 1;
				}
				else
				{
					count = MAXICOUNT;
				}

				int gid = geoPrimID*4 + instanceID*32;
				if( gid != 0 ) return;


				if( !nogo )
				{
					//uint ret = MiniRV32IMAStep( state, elapsedUs );
					uint ret = 0;
					
					
	uint32_t new_timer = CSR( timerl ) + elapsedUs;
	if( new_timer < CSR( timerl ) ) CSR( timerh )++;
	CSR( timerl ) = new_timer;

	// Handle Timer interrupt.
	if( ( CSR( timerh ) > CSR( timermatchh ) || ( CSR( timerh ) == CSR( timermatchh ) && CSR( timerl ) > CSR( timermatchl ) ) ) && ( CSR( timermatchh ) || CSR( timermatchl ) ) )
	{
		CSR( extraflags ) &= ~4; // Clear WFI
		CSR( mip ) |= 1<<7; //MTIP of MIP // https://stackoverflow.com/a/61916199/2926815  Fire interrupt.
	}
	else
		CSR( mip ) &= ~(1<<7);

	// If WFI, don't run processor.
	if( CSR( extraflags ) & 4 )
	{
		ret = 1;
		CSR( cpucounter ) = ( ( CSR( cpucounter ) + 1 ) & 0xfff ) | ( CSR( cpucounter ) & 0xfffff000 );
	}
	else
	{
		uint32_t trap = 0;
		uint32_t rval = 0;
		uint32_t pc = CSR( pcreg );
		uint32_t cycle = CSR( cyclel );
		uint icount = 0;

		if( ( CSR( mip ) & (1<<7) ) && ( CSR( mie ) & (1<<7) /*mtie*/ ) && ( CSR( mstatus ) & 0x8 /*mie*/) )
		{
			// Timer interrupt.
			trap = 0x80000007;
			pc -= 4;
		}
		else // No timer interrupt?  Execute a bunch of instructions.
		for( icount = 0; icount < count; icount++ )
		{
			uint32_t ir = 0;
			rval = 0;
			cycle++;
			uint32_t ofs_pc = pc - MINIRV32_RAM_IMAGE_OFFSET;

			if( ofs_pc >= MINI_RV32_RAM_SIZE )
			{
				trap = 1 + 1;  // Handle access violation on instruction read.
				break;
			}
			else if( ofs_pc & 3 )
			{
				trap = 1 + 0;  //Handle PC-misaligned access
				break;
			}
			else
			{
				ir = LoadMemInternalRB( ofs_pc );//MINIRV32_LOAD4( ofs_pc );
				uint32_t rdid = (ir >> 7) & 0x1f;

				switch( ir & 0x7f )
				{
					case 0x37: // LUI (0b0110111)
						rval = ( ir & 0xfffff000 );
						break;
					case 0x17: // AUIPC (0b0010111)
						rval = pc + ( ir & 0xfffff000 );
						break;
					case 0x6F: // JAL (0b1101111)
					{
						int32_t reladdy = ((ir & 0x80000000)>>11) | ((ir & 0x7fe00000)>>20) | ((ir & 0x00100000)>>9) | ((ir&0x000ff000));
						if( reladdy & 0x00100000 ) reladdy |= 0xffe00000; // Sign extension.
						rval = pc + 4;
						pc = pc + reladdy - 4;
						break;
					}
					case 0x67: // JALR (0b1100111)
					{
						uint32_t imm = ir >> 20;
						int32_t imm_se = imm | (( imm & 0x800 )?0xfffff000:0);
						rval = pc + 4;
						pc = ( (REG( (ir >> 15) & 0x1f ) + imm_se) & ~1) - 4;
						break;
					}
					case 0x63: // Branch (0b1100011)
					{
						uint32_t immm4 = ((ir & 0xf00)>>7) | ((ir & 0x7e000000)>>20) | ((ir & 0x80) << 4) | ((ir >> 31)<<12);
						if( immm4 & 0x1000 ) immm4 |= 0xffffe000;
						int32_t rs1 = REG((ir >> 15) & 0x1f);
						int32_t rs2 = REG((ir >> 20) & 0x1f);
						immm4 = pc + immm4 - 4;
						rdid = 0;
						switch( ( ir >> 12 ) & 0x7 )
						{
							// BEQ, BNE, BLT, BGE, BLTU, BGEU
							case 0: if( rs1 == rs2 ) pc = immm4; break;
							case 1: if( rs1 != rs2 ) pc = immm4; break;
							case 4: if( rs1 < rs2 ) pc = immm4; break;
							case 5: if( rs1 >= rs2 ) pc = immm4; break; //BGE
							case 6: if( (uint32_t)rs1 < (uint32_t)rs2 ) pc = immm4; break;   //BLTU
							case 7: if( (uint32_t)rs1 >= (uint32_t)rs2 ) pc = immm4; break;  //BGEU
							default: trap = (2+1); break;
						}
						break;
					}
					case 0x03: // Load (0b0000011)
					{
						uint32_t rs1 = REG((ir >> 15) & 0x1f);
						uint32_t imm = ir >> 20;
						int32_t imm_se = imm | (( imm & 0x800 )?0xfffff000:0);
						uint32_t rsval = rs1 + imm_se;

						rsval -= MINIRV32_RAM_IMAGE_OFFSET;
						if( rsval >= MINI_RV32_RAM_SIZE-3 )
						{
							rsval += MINIRV32_RAM_IMAGE_OFFSET;
							if( rsval >= 0x10000000 && rsval < 0x12000000 )  // UART, CLNT
							{
								if( rsval == 0x1100bffc ) // https://chromitem-soc.readthedocs.io/en/latest/clint.html
									rval = CSR( timerh );
								else if( rsval == 0x1100bff8 )
									rval = CSR( timerl );
								else
									MINIRV32_HANDLE_MEM_LOAD_CONTROL( rsval, rval );
							}
							else
							{
								trap = (5+1);
								rval = rsval;
							}
						}
						else
						{
#if 1
							//LB, LH, LW [invalid] LBU, LHU [invalid] [invalid]
							const uint btortable[] = { 1, 2, 4, 0, 1, 2, 0, 0 };
							const uint ebtable[] = { 0x80, 0x8000, 0, 0, 0, 0, 0, 0 };
							uint type_of_load = ( ir >> 12 ) & 0x7;
							uint btor = btortable[type_of_load];
							uint expandbyte = ebtable[type_of_load];
							uint ebor = -(expandbyte * 2);
							rval = LoadMemInternal( rsval, btor );
							rval |= -( (int)( rval & expandbyte ) << 1 ); // Compute bit-wise sign 2's compliment expansion (automatic sign extension)
							trap = ( btor == 0 ) ? (2+1) : 0;

#elif 1
							uint btor = 0;
							uint expandbyte = 0;
							switch( ( ir >> 12 ) & 0x7 )
							{
								//LB, LH, LW, LBU, LHU
								case 0: btor = 1; expandbyte = 0x80; break; //rval = MINIRV32_LOAD1_SIGNED( rsval ); break;
								case 1: btor = 2; expandbyte = 0x8000; break; //rval = MINIRV32_LOAD2_SIGNED( rsval ); break;
								case 2: btor = 4; break; //rval = MINIRV32_LOAD4( rsval ); break;
								case 4: btor = 1; break; //rval = MINIRV32_LOAD1( rsval ); break;
								case 5: btor = 2; break; //rval = MINIRV32_LOAD2( rsval ); break;
								default: trap = (2+1); break;
							}
							if( btor )
							{
								rval = LoadMemInternal( rsval, btor );
								if( rval & expandbyte )
								{
									rval |= ( btor == 1 ) ? 0xffffff00 : 0xffff0000;
								}
									
							}
							
#else // Ever so slightly faster (but chonky) Loads
							switch( ( ir >> 12 ) & 0x7 )
							{
								//LB, LH, LW, LBU, LHU
								case 0: rval = MINIRV32_LOAD1_SIGNED( rsval ); break;
								case 1: rval = MINIRV32_LOAD2_SIGNED( rsval ); break;
								case 2: rval = MINIRV32_LOAD4( rsval ); break;
								case 4: rval = MINIRV32_LOAD1( rsval ); break;
								case 5: rval = MINIRV32_LOAD2( rsval ); break;
								default: trap = (2+1); break;
							}
						
#endif
						
						}
						break;
					}
					case 0x23: // Store 0b0100011
					{
						uint32_t rs1 = REG((ir >> 15) & 0x1f);
						uint32_t rs2 = REG((ir >> 20) & 0x1f);
						uint32_t addy = ( ( ir >> 7 ) & 0x1f ) | ( ( ir & 0xfe000000 ) >> 20 );
						if( addy & 0x800 ) addy |= 0xfffff000;
						addy += rs1 - MINIRV32_RAM_IMAGE_OFFSET;
						rdid = 0;

						if( addy >= MINI_RV32_RAM_SIZE-3 )
						{
							addy += MINIRV32_RAM_IMAGE_OFFSET;
							if( addy >= 0x10000000 && addy < 0x12000000 )
							{
								// Should be stuff like SYSCON, 8250, CLNT
								if( addy == 0x11004004 ) //CLNT
									CSR( timermatchh ) = rs2;
								else if( addy == 0x11004000 ) //CLNT
									CSR( timermatchl ) = rs2;
								else if( addy == 0x11100000 ) //SYSCON (reboot, poweroff, etc.)
								{
									SETCSR( pcreg, pc + 4 );
									//return rs2; // NOTE: PC will be PC of Syscon.
								}
								else
									MINIRV32_HANDLE_MEM_STORE_CONTROL( addy, rs2 );
							}
							else
							{
								trap = (7+1); // Store access fault.
								rval = addy;
							}
						}
						else
						{
							uint nby = 0;
							switch( ( ir >> 12 ) & 0x7 )
							{
								//SB, SH, SW
								case 0: nby = 1; break;
								case 1: nby = 2; break;
								case 2: nby = 4; break;
								default: trap = (2+1); break;
							}
							if( nby )
							{
								StoreMemInternal( addy, rs2, nby );
								if( cache_usage >= MAX_FCNT ) icount = MAXICOUNT; 
							}
						}
						break;
					}
					case 0x13: // Op-immediate 0b0010011
					case 0x33: // Op           0b0110011
					{
						uint32_t imm = ir >> 20;
						imm = imm | (( imm & 0x800 )?0xfffff000:0);
						uint32_t rs1 = REG((ir >> 15) & 0x1f);
						uint32_t is_reg = !!( ir & 0x20 );
						uint32_t rs2 = is_reg ? REG(imm & 0x1f) : imm;

						if( is_reg && ( ir & 0x02000000 ) )
						{
							switch( (ir>>12)&7 ) //0x02000000 = RV32M
							{
								case 0: rval = rs1 * rs2; break; // MUL
	#ifndef CUSTOM_MULH // If compiling on a system that doesn't natively, or via libgcc support 64-bit math.
								case 1: rval = ((int64_t)((int32_t)rs1) * (int64_t)((int32_t)rs2)) >> 32; break; // MULH
								case 2: rval = ((int64_t)((int32_t)rs1) * (uint64_t)rs2) >> 32; break; // MULHSU
								case 3: rval = ((uint64_t)rs1 * (uint64_t)rs2) >> 32; break; // MULHU
	#else
								CUSTOM_MULH
	#endif
								case 4: if( rs2 == 0 ) rval = -1; else rval = ((int32_t)rs1 == INT32_MIN && (int32_t)rs2 == -1) ? rs1 : ((int32_t)rs1 / (int32_t)rs2); break; // DIV
								case 5: if( rs2 == 0 ) rval = 0xffffffff; else rval = rs1 / rs2; break; // DIVU
								case 6: if( rs2 == 0 ) rval = rs1; else rval = ((int32_t)rs1 == INT32_MIN && (int32_t)rs2 == -1) ? 0 : ((uint32_t)((int32_t)rs1 % (int32_t)rs2)); break; // REM
								case 7: if( rs2 == 0 ) rval = rs1; else rval = rs1 % rs2; break; // REMU
							}
						}
						else
						{
							switch( (ir>>12)&7 ) // These could be either op-immediate or op commands.  Be careful.
							{
								case 0: rval = (is_reg && (ir & 0x40000000) ) ? ( rs1 - rs2 ) : ( rs1 + rs2 ); break; 
								case 1: rval = rs1 << (rs2 & 0x1F); break;
								case 2: rval = (int32_t)rs1 < (int32_t)rs2; break;
								case 3: rval = rs1 < rs2; break;
								case 4: rval = rs1 ^ rs2; break;
								case 5: rval = (ir & 0x40000000 ) ? ( ((int32_t)rs1) >> (rs2 & 0x1F) ) : ( rs1 >> (rs2 & 0x1F) ); break;
								case 6: rval = rs1 | rs2; break;
								case 7: rval = rs1 & rs2; break;
							}
						}
						break;
					}
					case 0x0f: // 0b0001111
						rdid = 0;   // fencetype = (ir >> 12) & 0b111; We ignore fences in this impl.
						break;
					case 0x73: // Zifencei+Zicsr  (0b1110011)
					{
						uint32_t csrno = ir >> 20;
						uint32_t microop = ( ir >> 12 ) & 0x7;
						if( (microop & 3) ) // It's a Zicsr function.
						{
							int rs1imm = (ir >> 15) & 0x1f;
							uint32_t rs1 = REG(rs1imm);
							uint32_t writeval = rs1;

							// Unimplemented on this processor:
							
							int tcsr = scratch00;
							
							// https://raw.githubusercontent.com/riscv/virtual-memory/main/specs/663-Svpbmt.pdf
							// Generally, support for Zicsr
							switch( csrno )
							{
							case 0x340: tcsr = mscratch; break;
							case 0x305: tcsr = mtvec; break;
							case 0x304: tcsr = mie; break;
							case 0x344: tcsr = mip; break;
							case 0x341: tcsr = mepc; break;
							case 0x300: tcsr = mstatus; break; //mstatus
							case 0x342: tcsr = mcause; break;
							case 0x343: tcsr = mtval; break;
							case 0xf11: SETCSR( scratch00, 0xff0ff0ff ); break; //mvendorid
							case 0x301: SETCSR( scratch00, 0x40401101 ); break; //misa (XLEN=32, IMA+X)
							case 0xC00: SETCSR( scratch00, cycle ); break;
							default:
								SETCSR( scratch00, MINIRV32_OTHERCSR_READ( csrno, rval ) );
								break;
							}
							
							rval = CSR( tcsr ); 

							switch( microop )
							{
								case 1: writeval = rs1; break;  			//CSRRW
								case 2: writeval = rval | rs1; break;		//CSRRS
								case 3: writeval = rval & ~rs1; break;		//CSRRC
								case 5: writeval = rs1imm; break;			//CSRRWI
								case 6: writeval = rval | rs1imm; break;	//CSRRSI
								case 7: writeval = rval & ~rs1imm; break;	//CSRRCI
							}
							
							SETCSR( tcsr, writeval ); 

						}
						else if( microop == 0x0 ) // "SYSTEM" 0b000
						{
							rdid = 0;
							if( csrno == 0x105 ) //WFI (Wait for interrupts)
							{
								CSR( mstatus ) |= 8;    //Enable interrupts
								CSR( extraflags ) |= 4; //Infor environment we want to go to sleep.
								SETCSR( pcreg, pc + 4 );
								icount = MAXICOUNT;
								break;
							}
							else if( ( ( csrno & 0xff ) == 0x02 ) )  // MRET
							{
								//https://raw.githubusercontent.com/riscv/virtual-memory/main/specs/663-Svpbmt.pdf
								//Table 7.6. MRET then in mstatus/mstatush sets MPV=0, MPP=0, MIE=MPIE, and MPIE=1. La
								// Should also update mstatus to reflect correct mode.
								uint32_t startmstatus = CSR( mstatus );
								uint32_t startextraflags = CSR( extraflags );
								SETCSR( mstatus , (( startmstatus & 0x80) >> 4) | ((startextraflags&3) << 11) | 0x80 );
								SETCSR( extraflags, (startextraflags & ~3) | ((startmstatus >> 11) & 3) );
								pc = CSR( mepc ) -4;
							}
							else
							{
								switch( csrno )
								{
								case 0: trap = ( CSR( extraflags ) & 3) ? (11+1) : (8+1); break; // ECALL; 8 = "Environment call from U-mode"; 11 = "Environment call from M-mode"
								case 1:	trap = (3+1); break; // EBREAK 3 = "Breakpoint"
								default: trap = (2+1); break; // Illegal opcode.
								}
							}
						}
						else
							trap = (2+1); 				// Note micrrop 0b100 == undefined.
						break;
					}
					case 0x2f: // RV32A (0b00101111)
					{
						uint32_t rs1 = REG((ir >> 15) & 0x1f);
						uint32_t rs2 = REG((ir >> 20) & 0x1f);
						uint32_t irmid = ( ir>>27 ) & 0x1f;

						rs1 -= MINIRV32_RAM_IMAGE_OFFSET;

						// We don't implement load/store from UART or CLNT with RV32A here.

						if( rs1 >= MINI_RV32_RAM_SIZE-3 )
						{
							trap = (7+1); //Store/AMO access fault
							rval = rs1 + MINIRV32_RAM_IMAGE_OFFSET;
						}
						else
						{
							rval = LoadMemInternalRB( rs1 );
							//MINIRV32_LOAD4( rs1 );

							// Referenced a little bit of https://github.com/franzflasch/riscv_em/blob/master/src/core/core.c
							uint32_t dowrite = 1;
							switch( irmid )
							{
								case 2: //LR.W (0b00010)
									dowrite = 0;
									CSR( extraflags ) = (CSR( extraflags ) & 0x07) | (rs1<<3);
									break;
								case 3:  //SC.W (0b00011) (Make sure we have a slot, and, it's valid)
									rval = ( CSR( extraflags ) >> 3 != ( rs1 & 0x1fffffff ) );  // Validate that our reservation slot is OK.
									dowrite = !rval; // Only write if slot is valid.
									break;
								case 1: break; //AMOSWAP.W (0b00001)
								case 0: rs2 += rval; break; //AMOADD.W (0b00000)
								case 4: rs2 ^= rval; break; //AMOXOR.W (0b00100)
								case 12: rs2 &= rval; break; //AMOAND.W (0b01100)
								case 8: rs2 |= rval; break; //AMOOR.W (0b01000)
								case 16: rs2 = ((int32_t)rs2<(int32_t)rval)?rs2:rval; break; //AMOMIN.W (0b10000)
								case 20: rs2 = ((int32_t)rs2>(int32_t)rval)?rs2:rval; break; //AMOMAX.W (0b10100)
								case 24: rs2 = (rs2<rval)?rs2:rval; break; //AMOMINU.W (0b11000)
								case 28: rs2 = (rs2>rval)?rs2:rval; break; //AMOMAXU.W (0b11100)
								default: trap = (2+1); dowrite = 0; break; //Not supported.
							}
							if( dowrite ) 
							{ StoreMemInternalRB( rs1, rs2 ); if( cache_usage >= MAX_FCNT ) icount = MAXICOUNT; }
									//MINIRV32_STORE4( rs1, rs2 );
						}
						break;
					}
					default: trap = (2+1); break; // Fault: Invalid opcode.
				}

				// If there was a trap, do NOT allow register writeback.
				if( trap )
					break;

				if( rdid )
				{
					REGSET( rdid, rval ); // Write back register.
				}
			}

			MINIRV32_POSTEXEC( pc, ir, trap );

			pc += 4;
		}

		// Handle traps and interrupts.
		if( trap )
		{
			if( trap & 0x80000000 ) // If prefixed with 1 in MSB, it's an interrupt, not a trap.
			{
				SETCSR( mcause, trap );
				SETCSR( mtval, 0 );
				pc += 4; // PC needs to point to where the PC will return to.
			}
			else
			{
				SETCSR( mcause,  trap - 1 );
				SETCSR( mtval, (trap > 5 && trap <= 8)? rval : pc );
			}
			SETCSR( mepc, pc ); //TRICKY: The kernel advances mepc automatically.
			//CSR( mstatus ) & 8 = MIE, & 0x80 = MPIE
			// On an interrupt, the system moves current MIE into MPIE
			SETCSR( mstatus, (( CSR( mstatus ) & 0x08) << 4) | (( CSR( extraflags ) & 3 ) << 11) );
			pc = (CSR( mtvec ) - 4);

			// If trapping, always enter machine mode.
			CSR( extraflags ) |= 3;

			trap = 0;
			pc += 4;
		}

		if( CSR( cyclel ) > cycle ) CSR( cycleh )++;
		SETCSR( cyclel, cycle );
		SETCSR( pcreg, pc );
		CSR( cpucounter ) =  ( CSR( cpucounter ) & 0xff000fff ) | ( ( CSR( cpucounter ) + 0x1000 ) & 0xfff000 );
	}

					
					
				}

				
				for( i = 0; i < CACHE_BLOCKS; i++ )
				{
					uint a = cachesetsaddy[i];
					if( a > 0 )
					{
						uint2 coordOut = uint2( pixelOutputID, 0 + gid * 2  );
						o.vertex = ClipSpaceCoordinateOut( coordOut, float2(COMPUTE_OUT_X,COMPUTE_OUT_Y) );
						o.color = uint4(a, 0, 0, 0);
						stream.Append(o);
						coordOut = uint2( pixelOutputID++, 1 + gid * 2  );
						o.vertex = ClipSpaceCoordinateOut( coordOut, float2(COMPUTE_OUT_X,COMPUTE_OUT_Y) );
						o.color = cachesetsdata[i];
						stream.Append(o);
					}
				}
				
				CSR( cpucounter ) = ( CSR( cpucounter ) & 0x00ffffff ) | ( pixelOutputID << 24 );
				
				{
					uint4 statealias[13];
					for( i = 0; i < 13; i++ )
					{
						statealias[i] = uint4( state[i*4+0], state[i*4+1], state[i*4+2], state[i*4+3] );

						uint2 coordOut = uint2( 64-13+i, 0  + gid * 2  );
						o.vertex = ClipSpaceCoordinateOut( coordOut, float2(COMPUTE_OUT_X,COMPUTE_OUT_Y) );
						o.color = uint4((MINI_RV32_RAM_SIZE)/16+1+i, instanceID, geoPrimID, 0);
						stream.Append(o);
						coordOut = uint2( 64-13+i, 1 + gid * 2 );
						o.vertex = ClipSpaceCoordinateOut(coordOut, float2(COMPUTE_OUT_X,COMPUTE_OUT_Y) );
						o.color = statealias[i];
						stream.Append(o);
					}
				}
				
				#endif
			}


			uint4 frag( g2f IN ) : SV_Target
			{
				return IN.color;
			}

			ENDCG
		}
	}
}
