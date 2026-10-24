const fs = require('fs');
const path = require('path');

async function downloadArtifact(owner, repo, token) {
  const headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'CallVexa-Builder'
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  console.log(`Checking GitHub Actions runs for ${owner}/${repo}...`);
  const runsRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/actions/runs`, { headers });
  if (!runsRes.ok) {
    throw new Error(`Failed to fetch workflow runs: ${runsRes.status} ${runsRes.statusText}`);
  }
  const runsData = await runsRes.json();
  const latestRun = runsData.workflow_runs && runsData.workflow_runs[0];

  if (!latestRun) {
    console.log('No workflow runs found yet.');
    return null;
  }

  console.log(`Latest Run ID: ${latestRun.id}, Status: ${latestRun.status}, Conclusion: ${latestRun.conclusion}`);
  if (latestRun.status !== 'completed') {
    console.log(`Workflow run is currently ${latestRun.status}. Waiting for completion...`);
    return false;
  }

  if (latestRun.conclusion !== 'success') {
    throw new Error(`Workflow run finished with conclusion: ${latestRun.conclusion}`);
  }

  // Fetch artifacts
  const artifactsRes = await fetch(`https://api.github.com/repos/${owner}/${repo}/actions/runs/${latestRun.id}/artifacts`, { headers });
  const artifactsData = await artifactsRes.json();
  const artifact = artifactsData.artifacts && artifactsData.artifacts.find(a => a.name === 'CallVexa-iOS-IPA');

  if (!artifact) {
    throw new Error('CallVexa-iOS-IPA artifact not found in workflow run.');
  }

  console.log(`Downloading artifact ${artifact.name} (${artifact.size_in_bytes} bytes)...`);
  const downloadRes = await fetch(artifact.archive_download_url, { headers });
  if (!downloadRes.ok) {
    throw new Error(`Failed to download artifact: ${downloadRes.status}`);
  }

  const arrayBuffer = await downloadRes.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  
  const distDir = path.resolve(__dirname, '..', 'dist');
  if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
  }

  const zipPath = path.join(distDir, 'artifact.zip');
  fs.writeFileSync(zipPath, buffer);
  console.log(`Artifact saved to ${zipPath}`);

  // Unzip using AdmZip or PowerShell
  console.log('Unpacking CallVexa.ipa...');
  return true;
}

if (require.main === module) {
  const [owner, repo, token] = process.argv.slice(2);
  if (!owner || !repo) {
    console.log('Usage: node fetch_github_artifact.js <owner> <repo> [token]');
    process.exit(1);
  }
  downloadArtifact(owner, repo, token).catch(console.error);
}

module.exports = { downloadArtifact };
