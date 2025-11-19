#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { createClient } from '@supabase/supabase-js';

// Supabase configuration from Gavra Android project
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://gjtabtwudbrmfeyjiicu.supabase.co';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

// Initialize Supabase client
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Admin client for operations requiring elevated permissions
const adminSupabase = SUPABASE_SERVICE_ROLE_KEY
    ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    : null;

class GavraMCPServer {
    private server: Server;

    constructor() {
        this.server = new Server(
            {
                name: 'gavra-mcp-supabase-server',
                version: '1.0.0',
            },
            {
                capabilities: {
                    tools: {},
                },
            }
        );

        this.setupToolHandlers();

        // Error handling
        this.server.onerror = (error) => console.error('[MCP Error]', error);
        process.on('SIGINT', async () => {
            await this.server.close();
            process.exit(0);
        });
    }

    private setupToolHandlers() {
        // List available tools
        this.server.setRequestHandler(ListToolsRequestSchema, async () => {
            return {
                tools: [
                    {
                        name: 'get_vozaci',
                        description: 'Dobij sve vozače iz baze podataka',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                aktivan: {
                                    type: 'boolean',
                                    description: 'Filter samo aktivne vozače',
                                    default: true
                                }
                            }
                        }
                    },
                    {
                        name: 'get_mesecni_putnici',
                        description: 'Dobij mesečne putnike',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                aktivan: {
                                    type: 'boolean',
                                    description: 'Filter samo aktivne putnike',
                                    default: true
                                },
                                limit: {
                                    type: 'number',
                                    description: 'Maksimalan broj rezultata',
                                    default: 50
                                }
                            }
                        }
                    },
                    {
                        name: 'get_dnevni_putnici',
                        description: 'Dobij dnevne putnike za određeni datum',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                datum: {
                                    type: 'string',
                                    description: 'Datum u YYYY-MM-DD formatu',
                                    default: new Date().toISOString().split('T')[0]
                                },
                                limit: {
                                    type: 'number',
                                    description: 'Maksimalan broj rezultata',
                                    default: 100
                                }
                            }
                        }
                    },
                    {
                        name: 'get_putovanja_istorija',
                        description: 'Dobij istoriju putovanja',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                vozac_id: {
                                    type: 'string',
                                    description: 'UUID vozača za filtriranje'
                                },
                                from_date: {
                                    type: 'string',
                                    description: 'Početni datum (YYYY-MM-DD)'
                                },
                                to_date: {
                                    type: 'string',
                                    description: 'Završni datum (YYYY-MM-DD)'
                                },
                                limit: {
                                    type: 'number',
                                    description: 'Maksimalan broj rezultata',
                                    default: 100
                                }
                            }
                        }
                    },
                    {
                        name: 'get_vozac_by_ime',
                        description: 'Pronađi vozača po imenu',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                ime: {
                                    type: 'string',
                                    description: 'Ime vozača'
                                }
                            },
                            required: ['ime']
                        }
                    },
                    {
                        name: 'get_vozac_kusur',
                        description: 'Dobij kusur vozača',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                vozac_ime: {
                                    type: 'string',
                                    description: 'Ime vozača'
                                }
                            },
                            required: ['vozac_ime']
                        }
                    },
                    {
                        name: 'update_vozac_kusur',
                        description: 'Ažuriraj kusur vozača (zahteva admin privilegije)',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                vozac_ime: {
                                    type: 'string',
                                    description: 'Ime vozača'
                                },
                                novi_kusur: {
                                    type: 'number',
                                    description: 'Nova vrednost kusura'
                                }
                            },
                            required: ['vozac_ime', 'novi_kusur']
                        }
                    },
                    {
                        name: 'get_statistike',
                        description: 'Dobij statistike za vozače',
                        inputSchema: {
                            type: 'object',
                            properties: {
                                vozac_ime: {
                                    type: 'string',
                                    description: 'Ime vozača za statistike'
                                }
                            },
                            required: ['vozac_ime']
                        }
                    }
                ]
            };
        });

        // Handle tool calls
        this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
            const { name, arguments: args } = request.params;

            try {
                switch (name) {
                    case 'get_vozaci':
                        return await this.getVozaci(args);
                    case 'get_mesecni_putnici':
                        return await this.getMesecniPutnici(args);
                    case 'get_dnevni_putnici':
                        return await this.getDnevniPutnici(args);
                    case 'get_putovanja_istorija':
                        return await this.getPutovanjaIstorija(args);
                    case 'get_vozac_by_ime':
                        return await this.getVozacByIme(args);
                    case 'get_vozac_kusur':
                        return await this.getVozacKusur(args);
                    case 'update_vozac_kusur':
                        return await this.updateVozacKusur(args);
                    case 'get_statistike':
                        return await this.getStatistike(args);
                    default:
                        throw new Error(`Unknown tool: ${name}`);
                }
            } catch (error) {
                return {
                    content: [
                        {
                            type: 'text',
                            text: `Error: ${error instanceof Error ? error.message : String(error)}`
                        }
                    ]
                };
            }
        });
    }

    private async getVozaci(args: any) {
        const { aktivan = true } = args;

        let query = supabase
            .from('vozaci')
            .select('id, ime, boja, kusur, aktivan, created_at, updated_at');

        if (aktivan) {
            query = query.eq('aktivan', true);
        }

        const { data, error } = await query.order('ime');

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Pronađeno ${data.length} vozača:\n\n${JSON.stringify(data, null, 2)}`
                }
            ]
        };
    }

    private async getMesecniPutnici(args: any) {
        const { aktivan = true, limit = 50 } = args;

        let query = supabase
            .from('mesecni_putnici')
            .select('*');

        if (aktivan) {
            query = query.eq('aktivan', true);
        }

        const { data, error } = await query
            .order('putnik_ime')
            .limit(limit);

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Pronađeno ${data.length} mesečnih putnika:\n\n${JSON.stringify(data, null, 2)}`
                }
            ]
        };
    }

    private async getDnevniPutnici(args: any) {
        const { datum = new Date().toISOString().split('T')[0], limit = 100 } = args;

        const { data, error } = await supabase
            .from('dnevni_putnici')
            .select('*')
            .eq('datum_polaska', datum)
            .order('vreme_polaska')
            .limit(limit);

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Pronađeno ${data.length} dnevnih putnika za ${datum}:\n\n${JSON.stringify(data, null, 2)}`
                }
            ]
        };
    }

    private async getPutovanjaIstorija(args: any) {
        const { vozac_id, from_date, to_date, limit = 100 } = args;

        let query = supabase
            .from('putovanja_istorija')
            .select('*');

        if (vozac_id) {
            query = query.eq('vozac_id', vozac_id);
        }

        if (from_date) {
            query = query.gte('datum_putovanja', from_date);
        }

        if (to_date) {
            query = query.lte('datum_putovanja', to_date);
        }

        const { data, error } = await query
            .order('datum_putovanja', { ascending: false })
            .limit(limit);

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Pronađeno ${data.length} putovanja u istoriji:\n\n${JSON.stringify(data, null, 2)}`
                }
            ]
        };
    }

    private async getVozacByIme(args: any) {
        const { ime } = args;

        const { data, error } = await supabase
            .from('vozaci')
            .select('*')
            .eq('ime', ime)
            .eq('aktivan', true)
            .maybeSingle();

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: data
                        ? `Vozač pronađen:\n\n${JSON.stringify(data, null, 2)}`
                        : `Vozač sa imenom '${ime}' nije pronađen.`
                }
            ]
        };
    }

    private async getVozacKusur(args: any) {
        const { vozac_ime } = args;

        const { data, error } = await supabase
            .rpc('get_vozac_kusur', { p_vozac_ime: vozac_ime });

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Kusur za vozača '${vozac_ime}': ${data} RSD`
                }
            ]
        };
    }

    private async updateVozacKusur(args: any) {
        if (!adminSupabase) {
            throw new Error('Admin privilegije nisu dostupne. Postavi SUPABASE_SERVICE_ROLE_KEY environment varijablu.');
        }

        const { vozac_ime, novi_kusur } = args;

        const { error } = await adminSupabase
            .rpc('update_vozac_kusur', {
                vozac_ime: vozac_ime,
                novi_kusur: novi_kusur
            });

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Kusur za vozača '${vozac_ime}' je ažuriran na ${novi_kusur} RSD`
                }
            ]
        };
    }

    private async getStatistike(args: any) {
        const { vozac_ime } = args;

        const { data, error } = await supabase
            .rpc('get_vozac_statistike', { p_vozac_ime: vozac_ime });

        if (error) throw error;

        return {
            content: [
                {
                    type: 'text',
                    text: `Statistike za vozača '${vozac_ime}':\n\n${JSON.stringify(data, null, 2)}`
                }
            ]
        };
    }

    async run() {
        const transport = new StdioServerTransport();
        await this.server.connect(transport);
        console.error('Gavra MCP Supabase Server pokrenut na stdio');
    }
}

const server = new GavraMCPServer();
server.run().catch(console.error);