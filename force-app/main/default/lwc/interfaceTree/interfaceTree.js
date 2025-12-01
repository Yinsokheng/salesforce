import { LightningElement, track } from 'lwc';
import getRootIntegrations from '@salesforce/apex/InterfaceTreeController.getRootIntegrations';
import getInterfaces from '@salesforce/apex/InterfaceTreeController.getInterfaces';
import getMessages from '@salesforce/apex/InterfaceTreeController.getMessages';

export default class InterfaceTree extends LightningElement {
    @track treeData = [];
    @track loading = false;

    connectedCallback() {
        this.loadRoot();
    }

    async loadRoot() {
        this.loading = true;
        try {
            const roots = await getRootIntegrations();
            this.treeData = roots.map(r => ({
                ...r,
                expanded: false,
                children: [],
                loadingChildren: false
            }));
        } catch (err) {
            console.error(err);
        } finally {
            this.loading = false;
        }
    }

    async handleToggle(event) {
        const { nodeId } = event.detail;
        const node = this.findNodeById(this.treeData, nodeId);
        if (!node) return;

        node.expanded = !node.expanded;
        if (node.expanded && node.hasChildren && node.children.length === 0) {
            node.loadingChildren = true;

            try {
                let children = [];
                if (node.type === 'integration') {
                    children = await getInterfaces({ integrationId: node.id });
                } else if (node.type === 'interface') {
                    children = await getMessages({ interfaceId: node.id });
                }

                node.children = children.map(c => ({
                    ...c,
                    expanded: false,
                    children: [],
                    loadingChildren: false
                }));
            } catch (err) {
                console.error('Error loading children', err);
            } finally {
                node.loadingChildren = false;
                this.treeData = [...this.treeData]; // re-render
            }
        } else {
            this.treeData = [...this.treeData];
        }
    }

    handleSelect(event) {
        const { nodeId } = event.detail;
        const node = this.findNodeById(this.treeData, nodeId);
        if (node) {
            this.dispatchEvent(new CustomEvent('select', { detail: node }));
        }
    }

    findNodeById(nodes, id) {
        for (const node of nodes) {
            if (node.id === id) return node;
            if (node.children?.length) {
                const found = this.findNodeById(node.children, id);
                if (found) return found;
            }
        }
        return null;
    }

    handleLookupSelection(event) {
        console.log('Selected record:', event.detail);
    }

}